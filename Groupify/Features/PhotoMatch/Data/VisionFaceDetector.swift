import CoreGraphics
import UIKit
import Vision

struct VisionFaceDetector: FaceDetector, Sendable {

    /// Detects all faces in the image. The UIImage is first normalized to an
    /// upright bitmap via `ImageNormalizer` so that Vision always operates on
    /// correctly-oriented pixels. Bounding boxes are returned in normalized
    /// coordinates with **top-left origin** (converted from Vision's bottom-left),
    /// sorted by area descending.
    nonisolated func detectFaces(in image: UIImage) async throws -> [DetectedFace] {
        // 1. Normalize to upright CGImage — strips EXIF orientation.
        guard let normalized = ImageNormalizer.normalizeUpright(from: image) else {
            return []
        }
        let uprightCG = normalized.cgImage

        #if DEBUG
        print("[VisionFaceDetector] Normalized image size: \(Int(normalized.size.width))×\(Int(normalized.size.height))")
        #endif

        // 2. Run Vision face detection on the upright image.
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNFaceObservation]) ?? []

                #if DEBUG
                print("[VisionFaceDetector] Detected \(observations.count) face(s)")
                #endif

                // Convert from Vision bottom-left origin to top-left origin.
                let faces: [DetectedFace] = observations.enumerated().map { idx, obs in
                    let vbb = obs.boundingBox
                    let box = FaceBoundingBox(
                        x:      Float(vbb.origin.x),
                        y:      Float(1.0 - vbb.origin.y - vbb.height),
                        width:  Float(vbb.width),
                        height: Float(vbb.height)
                    )
                    #if DEBUG
                    print("[VisionFaceDetector]   Face \(idx): x=\(box.x) y=\(box.y) w=\(box.width) h=\(box.height) confidence=\(obs.confidence)")
                    #endif
                    return DetectedFace(boundingBox: box, confidence: obs.confidence)
                }

                // Sort by area descending (largest first).
                let sorted = faces.sorted { $0.boundingBox.area > $1.boundingBox.area }
                continuation.resume(returning: sorted)
            }

            // Use revision 3 when available for better detection of small/angled faces.
            if #available(iOS 15.0, *) {
                request.revision = VNDetectFaceRectanglesRequestRevision3
            }

            let handler = VNImageRequestHandler(cgImage: uprightCG, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
