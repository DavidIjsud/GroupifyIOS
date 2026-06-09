import Foundation
import Photos
import UIKit

/// Incrementally CLIP-indexes library photos added since `since`, storing one
/// scene embedding per asset (no face detection). Mirrors `IndexLibraryUseCase`
/// but with a single embedding per photo, deduped by `assetIdentifier`.
struct IndexLibrarySceneUseCase: Sendable {
    let photoService: any PhotoLibraryService
    let embedder: any SceneEmbedder
    let repository: any SceneIndexRepository

    /// CLIP downscales to ~256² internally; a modest thumbnail keeps scanning fast
    /// while preserving enough scene detail for the encoder.
    private nonisolated static let thumbSize = CGSize(width: 256, height: 256)

    struct Progress: Sendable {
        let current: Int
        let total: Int
        let status: String
        var fraction: Float { total > 0 ? Float(current) / Float(total) : 0 }
    }

    struct Result: Sendable {
        let indexedNewScenes: Int
        let scannedNewAssets: Int
        let totalInIndex: Int
    }

    /// Calls `onProgress` from a background context — callers must dispatch to MainActor.
    nonisolated func execute(
        since: Date?,
        onProgress: @escaping @Sendable (Progress) -> Void
    ) async throws -> Result {
        let existingRecords = (try? await repository.loadRecords()) ?? []
        let existingIds = Set(existingRecords.map(\.assetIdentifier))

        let assets = photoService.fetchAssets(newerThan: since)
        let total = assets.count

        if total == 0 {
            onProgress(Progress(current: 0, total: 0, status: L10n.indexUpToDate))
            return Result(
                indexedNewScenes: 0,
                scannedNewAssets: 0,
                totalInIndex: existingRecords.count
            )
        }

        var newScenes = [IndexedScene]()

        for (i, asset) in assets.enumerated() {
            onProgress(Progress(
                current: i + 1, total: total,
                status: L10n.scanningScenesProgress(current: i + 1, total: total)
            ))

            if existingIds.contains(asset.localIdentifier) { continue }

            do {
                let thumb = try await photoService.loadThumbnail(
                    for: asset, targetSize: Self.thumbSize
                )
                guard let cg = thumb.cgImage else { continue }

                let embedding = try await embedder.embedImage(cg)
                newScenes.append(IndexedScene(
                    assetIdentifier: asset.localIdentifier,
                    embedding: embedding,
                    dateIndexed: Date()
                ))
            } catch {
                // Skip individual failures — continue indexing.
                continue
            }
        }

        if !newScenes.isEmpty {
            try await repository.append(newScenes: newScenes)
        }

        return Result(
            indexedNewScenes: newScenes.count,
            scannedNewAssets: total,
            totalInIndex: existingRecords.count + newScenes.count
        )
    }
}
