import Foundation
import UIKit

struct SearchByPhotoUseCase: Sendable {
    let embedder: any FaceEmbedder
    let repository: any FaceIndexRepository

    enum SearchError: Error, LocalizedError {
        case noFacesSelected
        case cropFailed

        var errorDescription: String? {
            switch self {
            case .noFacesSelected: return L10n.errorSelectAtLeastOneFace
            case .cropFailed:      return L10n.errorCropFailed
            }
        }
    }

    /// Searches the index using one or more selected face bounding boxes from
    /// the query image. For each indexed photo, keeps the best similarity score
    /// across all selected query faces.
    nonisolated func execute(
        queryImage: UIImage,
        selectedFaces: [FaceBoundingBox]
    ) async throws -> [PhotoMatch] {
        guard !selectedFaces.isEmpty else {
            throw SearchError.noFacesSelected
        }

        // 1. Compute embedding for each selected face.
        var queryVectors = [[Float]]()
        for box in selectedFaces {
            guard let cropped = FaceCropper.crop(
                from: queryImage, boundingBox: box
            ) else {
                continue
            }
            let embedding = try await embedder.computeEmbedding(faceImage: cropped)
            queryVectors.append(l2Normalize(embedding.values))
        }

        guard !queryVectors.isEmpty else {
            throw SearchError.cropFailed
        }

        // 2. Load index and rank.
        let index = try await repository.load()

        // For each indexed face, take the max similarity across all query vectors.
        var bestScores = [String: Float]() // assetIdentifier -> best score
        for indexed in index {
            let iVec = l2Normalize(indexed.embedding.values)
            var best: Float = 0
            for qVec in queryVectors {
                let score = dotProduct(qVec, iVec)
                best = max(best, score)
            }
            let existing = bestScores[indexed.assetIdentifier] ?? 0
            bestScores[indexed.assetIdentifier] = max(existing, best)
        }

        let matches = bestScores.map {
            PhotoMatch(assetIdentifier: $0.key, similarityScore: max(0, $0.value))
        }
        return matches.sorted { $0.similarityScore > $1.similarityScore }
    }

    // MARK: - Math

    private nonisolated func l2Normalize(_ v: [Float]) -> [Float] {
        let mag = sqrt(v.reduce(0) { $0 + $1 * $1 })
        guard mag > 0 else { return v }
        return v.map { $0 / mag }
    }

    private nonisolated func dotProduct(_ a: [Float], _ b: [Float]) -> Float {
        zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
    }
}
