import Foundation
import UIKit

struct DetectQueryFacesUseCase: Sendable {
    let detector: any FaceDetector

    enum QueryFaceError: Error, LocalizedError {
        case invalidImage
        case noFacesDetected

        var errorDescription: String? {
            switch self {
            case .invalidImage:     return "The selected image could not be processed"
            case .noFacesDetected:  return "No faces detected in this photo"
            }
        }
    }

    /// Detects all faces in the query image and returns them sorted by area
    /// descending (largest first). Each face gets a stable ID derived from
    /// the image hash and its index in the sorted list.
    nonisolated func execute(
        queryImage: UIImage,
        imageIdentifier: String
    ) async throws -> [QueryFace] {
        guard let cgImage = queryImage.cgImage else {
            throw QueryFaceError.invalidImage
        }

        let detected = try await detector.detectFaces(in: cgImage)
        guard !detected.isEmpty else {
            throw QueryFaceError.noFacesDetected
        }

        // Sort by area descending so index 0 = largest face.
        let sorted = detected.sorted { $0.boundingBox.area > $1.boundingBox.area }

        return sorted.enumerated().map { index, face in
            // Stable ID: hash of imageIdentifier + face index in the sorted list.
            var hasher = Hasher()
            hasher.combine(imageIdentifier)
            hasher.combine(index)
            let stableId = abs(hasher.finalize())
            return QueryFace(id: stableId, boundingBox: face.boundingBox)
        }
    }
}
