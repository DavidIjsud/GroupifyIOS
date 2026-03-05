import Foundation
import Photos
import UIKit

struct IndexLibraryUseCase: Sendable {
    let photoService: any PhotoLibraryService
    let detector: any FaceDetector
    let embedder: any FaceEmbedder
    let repository: any FaceIndexRepository

    struct Progress: Sendable {
        let current: Int
        let total: Int
        let status: String
        var fraction: Float { total > 0 ? Float(current) / Float(total) : 0 }
    }

    struct Result: Sendable {
        let indexedNew: Int
        let skippedExisting: Int
        let totalInIndex: Int
    }

    /// Incrementally indexes all library photos.
    /// Only indexes faces not already present (deduped by assetIdentifier + faceIndex).
    /// Calls `onProgress` from a background context — callers must dispatch to MainActor.
    nonisolated func execute(
        onProgress: @escaping @Sendable (Progress) -> Void
    ) async throws -> Result {
        // Load existing records for dedup (lightweight — no embeddings loaded).
        let existingRecords = (try? await repository.loadRecords()) ?? []
        let existingKeys = Set(existingRecords.map(\.dedupeKey))

        let assets = photoService.fetchAllAssets()
        let total = assets.count

        if total == 0 {
            onProgress(Progress(current: 0, total: 0, status: L10n.indexUpToDate))
            return Result(
                indexedNew: 0,
                skippedExisting: existingRecords.count,
                totalInIndex: existingRecords.count
            )
        }

        var newFaces = [IndexedFace]()
        var skippedExisting = 0
        let thumbSize = CGSize(width: 300, height: 300)

        for (i, asset) in assets.enumerated() {
            onProgress(Progress(
                current: i + 1, total: total,
                status: L10n.indexingProgress(current: i + 1, total: total)
            ))

            do {
                let thumb = try await photoService.loadThumbnail(
                    for: asset, targetSize: thumbSize
                )
                guard let cgImage = thumb.cgImage else { continue }

                let detectedFaces = try await detector.detectFaces(in: cgImage)
                if detectedFaces.isEmpty { continue }

                // Sort faces by area descending for consistent indexing order.
                let sortedFaces = detectedFaces.sorted { $0.boundingBox.area > $1.boundingBox.area }

                for (faceIdx, face) in sortedFaces.enumerated() {
                    let key = "\(asset.localIdentifier)#\(faceIdx)"
                    if existingKeys.contains(key) {
                        skippedExisting += 1
                        continue
                    }

                    guard let cropped = FaceCropper.crop(
                        from: thumb, boundingBox: face.boundingBox
                    ) else { continue }

                    let embedding = try await embedder.computeEmbedding(faceImage: cropped)
                    newFaces.append(IndexedFace(
                        assetIdentifier: asset.localIdentifier,
                        faceIndexInAsset: faceIdx,
                        boundingBox: face.boundingBox,
                        embedding: embedding,
                        dateIndexed: Date()
                    ))
                }
            } catch {
                // Skip individual failures — continue indexing.
                continue
            }
        }

        // Append only new faces to the index.
        if !newFaces.isEmpty {
            try await repository.append(newFaces: newFaces)
        }

        let totalInIndex = existingRecords.count + newFaces.count
        return Result(
            indexedNew: newFaces.count,
            skippedExisting: skippedExisting,
            totalInIndex: totalInIndex
        )
    }
}
