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

    /// Indexes all library photos that aren't already in the index.
    /// Calls `onProgress` from a background context — callers must dispatch to MainActor.
    nonisolated func execute(
        onProgress: @escaping @Sendable (Progress) -> Void
    ) async throws -> [IndexedFace] {
        let existing = (try? await repository.load()) ?? []
        let existingIds = Set(existing.map(\.assetIdentifier))

        let assets = photoService.fetchAllAssets()
        let newAssets = assets.filter { !existingIds.contains($0.localIdentifier) }
        let total = newAssets.count

        if total == 0 {
            onProgress(Progress(current: 0, total: 0, status: "Index is up to date"))
            return existing
        }

        var results = existing
        let thumbSize = CGSize(width: 300, height: 300)

        for (i, asset) in newAssets.enumerated() {
            onProgress(Progress(
                current: i + 1, total: total,
                status: "Indexing \(i + 1) of \(total)…"
            ))

            do {
                let thumb = try await photoService.loadThumbnail(
                    for: asset, targetSize: thumbSize
                )
                guard let cgImage = thumb.cgImage else { continue }

                let faces = try await detector.detectFaces(in: cgImage)
                // Pick the face with the largest bounding box area.
                guard let best = faces.max(by: { $0.boundingBox.area < $1.boundingBox.area })
                else { continue }

                guard let cropped = FaceCropper.crop(
                    from: thumb, boundingBox: best.boundingBox
                ) else { continue }

                let embedding = try await embedder.computeEmbedding(faceImage: cropped)
                results.append(IndexedFace(
                    assetIdentifier: asset.localIdentifier,
                    embedding: embedding,
                    dateIndexed: Date()
                ))
            } catch {
                // Skip individual failures — continue indexing.
                continue
            }
        }

        try await repository.save(results)
        return results
    }
}
