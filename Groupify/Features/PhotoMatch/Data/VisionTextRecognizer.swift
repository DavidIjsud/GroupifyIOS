import UIKit
import Vision

struct VisionTextRecognizer: TextRecognizer, Sendable {

    /// Recognizes visible text in the image, on-device. The UIImage is first
    /// normalized to an upright bitmap via `ImageNormalizer` (same contract as
    /// `VisionFaceDetector`) so Vision always operates on correctly-oriented
    /// pixels. Returns the recognized lines joined with newlines (empty string
    /// if no text was found).
    nonisolated func recognizeText(in image: UIImage) async throws -> String {
        // 1. Normalize to upright CGImage — strips EXIF orientation.
        guard let normalized = ImageNormalizer.normalizeUpright(from: image) else {
            return ""
        }
        let uprightCG = normalized.cgImage

        // 2. Run Vision text recognition on the upright image.
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                // Keep the top candidate per observation (one per text region).
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }

                #if DEBUG
                print("[VisionTextRecognizer] Recognized \(lines.count) text line(s)")
                #endif

                continuation.resume(returning: lines.joined(separator: "\n"))
            }

            // Accurate level + language correction for readable receipts/labels.
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            // Match the app's localizations.
            request.recognitionLanguages = ["en-US", "es-ES"]

            let handler = VNImageRequestHandler(cgImage: uprightCG, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
