import CoreGraphics
import Foundation

/// Deterministic fallback `SceneEmbedder` used when the MobileCLIP models (or the
/// BPE vocab) are missing from the bundle. It lets the whole "describe the scene"
/// flow compile and run end-to-end, but matching is effectively arbitrary —
/// image and text vectors don't share real CLIP semantics. The factory surfaces a
/// clear warning when this is active. Mirrors `StubFaceEmbedder`.
///
/// TODO: This is only the degraded path; real quality comes from `CoreMLSceneEmbedder`.
struct StubSceneEmbedder: SceneEmbedder, Sendable {
    private nonisolated static let outputDim = 512
    private nonisolated static let gridSize = 16   // 16×16 = 256 pixel samples

    // MARK: - Image

    nonisolated func embedImage(_ image: CGImage) async throws -> [Float] {
        let g = Self.gridSize

        guard let ctx = CGContext(
            data: nil,
            width: g, height: g,
            bitsPerComponent: 8,
            bytesPerRow: g * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw StubSceneError.contextCreationFailed
        }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: g, height: g))

        guard let pixelData = ctx.data else {
            throw StubSceneError.pixelReadFailed
        }
        let ptr = pixelData.bindMemory(to: UInt8.self, capacity: g * g * 4)

        // 256 grayscale samples → expand to 512 with a deterministic transform.
        var values = [Float](repeating: 0, count: Self.outputDim)
        for i in 0..<(g * g) {
            let r = Float(ptr[i * 4])
            let green = Float(ptr[i * 4 + 1])
            let b = Float(ptr[i * 4 + 2])
            let gray = (0.299 * r + 0.587 * green + 0.114 * b) / 255.0
            values[i] = gray
            values[i + g * g] = sin(Float(i + 1) * gray * .pi)
        }

        return Self.normalized(values)
    }

    // MARK: - Text

    nonisolated func embedText(_ text: String) async throws -> [Float] {
        // Deterministic bag-of-characters hash spread across the vector. Purely a
        // placeholder so the pipeline runs; not semantically meaningful.
        var values = [Float](repeating: 0, count: Self.outputDim)
        let lower = text.lowercased()
        for (i, scalar) in lower.unicodeScalars.enumerated() {
            let bucket = Int(scalar.value) % Self.outputDim
            values[bucket] += 1
            let phase = Float((Int(scalar.value) &* (i + 1)) % Self.outputDim)
            values[(bucket + 1) % Self.outputDim] += sin(phase)
        }
        return Self.normalized(values)
    }

    // MARK: - Helpers

    private nonisolated static func normalized(_ input: [Float]) -> [Float] {
        var values = input
        let magnitude = sqrt(values.reduce(0) { $0 + $1 * $1 })
        if magnitude > 0 {
            for i in values.indices { values[i] /= magnitude }
        }
        return values
    }

    enum StubSceneError: Error {
        case contextCreationFailed
        case pixelReadFailed
    }
}
