import Foundation
import UIKit

struct DetectQueryFacesUseCase: Sendable {
    let detector: any FaceDetector

    enum QueryFaceError: Error, LocalizedError {
        case invalidImage
        case noFacesDetected

        var errorDescription: String? {
            switch self {
            case .invalidImage:     return L10n.errorInvalidImage
            case .noFacesDetected:  return L10n.errorNoFacesDetected
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
        // Detector now handles normalization internally and returns
        // faces sorted by area descending.
        let detected = try await detector.detectFaces(in: queryImage)
        guard !detected.isEmpty else {
            throw QueryFaceError.noFacesDetected
        }

        return detected.enumerated().map { index, face in
            // Stable ID: hash of imageIdentifier + face index in the sorted list.
            var hasher = Hasher()
            hasher.combine(imageIdentifier)
            hasher.combine(index)
            let stableId = abs(hasher.finalize())
            return QueryFace(id: stableId, boundingBox: face.boundingBox)
        }
    }
}
