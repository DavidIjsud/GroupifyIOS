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
            queryVectors.append(embedding.values)
        }

        guard !queryVectors.isEmpty else {
            throw SearchError.cropFailed
        }

        // 2. Load index and rank using Accelerate-backed Top-K search.
        let index = try await repository.load()

        return EmbeddingSearchEngine.topKMatches(
            queryVectors: queryVectors,
            indexedFaces: index
        )
    }
}
