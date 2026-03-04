import CoreGraphics
import Vision

struct VisionFaceDetector: FaceDetector, Sendable {
    nonisolated func detectFaces(in image: CGImage) async throws -> [DetectedFace] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNFaceObservation]) ?? []
                let faces: [DetectedFace] = observations.map { obs in
                    let vbb = obs.boundingBox
                    // Vision: origin at bottom-left, Y up.
                    // Convert to top-left origin: topY = 1 - bottomY - height
                    let box = FaceBoundingBox(
                        x:      Float(vbb.origin.x),
                        y:      Float(1.0 - vbb.origin.y - vbb.height),
                        width:  Float(vbb.width),
                        height: Float(vbb.height)
                    )
                    return DetectedFace(boundingBox: box, confidence: obs.confidence)
                }
                continuation.resume(returning: faces)
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
