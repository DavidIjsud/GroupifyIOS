import Foundation
import UIKit

struct SearchByPhotoUseCase: Sendable {
    let detector: any FaceDetector
    let embedder: any FaceEmbedder
    let repository: any FaceIndexRepository

    enum SearchError: Error, LocalizedError {
        case invalidImage
        case noFaceDetected
        case cropFailed

        var errorDescription: String? {
            switch self {
            case .invalidImage:    return "The selected image could not be processed"
            case .noFaceDetected:  return "No face detected in the selected photo"
            case .cropFailed:      return "Failed to crop the detected face"
            }
        }
    }

    /// Detects the largest face in `queryImage`, embeds it, and ranks the
    /// stored index by cosine similarity.
    nonisolated func execute(queryImage: UIImage) async throws -> [PhotoMatch] {
        guard let cgImage = queryImage.cgImage else {
            throw SearchError.invalidImage
        }

        // 1. Detect faces in query.
        let faces = try await detector.detectFaces(in: cgImage)
        guard !faces.isEmpty else { throw SearchError.noFaceDetected }

        // 2. Pick the largest face.
        let largest = faces.max { $0.boundingBox.area < $1.boundingBox.area }!
        guard let cropped = FaceCropper.crop(
            from: queryImage, boundingBox: largest.boundingBox
        ) else {
            throw SearchError.cropFailed
        }

        // 3. Compute embedding.
        let queryEmbedding = try await embedder.computeEmbedding(faceImage: cropped)
        let qVec = l2Normalize(queryEmbedding.values)

        // 4. Load index and rank by cosine similarity.
        let index = try await repository.load()
        let matches: [PhotoMatch] = index.map { indexed in
            let iVec = l2Normalize(indexed.embedding.values)
            let score = dotProduct(qVec, iVec)
            return PhotoMatch(
                assetIdentifier: indexed.assetIdentifier,
                similarityScore: max(0, score)
            )
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
