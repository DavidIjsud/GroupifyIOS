import CoreGraphics
import Foundation

// TODO: Replace with a real CoreML FaceNet / MobileFaceNet model.
// The protocol contract (FaceEmbedder) stays the same — only swap this struct.
struct StubFaceEmbedder: FaceEmbedder, Sendable {
    private nonisolated static let gridSize = 8      // 8×8 = 64 pixel samples
    private nonisolated static let outputDim = 128   // 64 raw + 64 expanded = 128

    nonisolated func computeEmbedding(faceImage: CGImage) async throws -> FaceEmbedding {
        let g = Self.gridSize

        // Render face into a tiny g×g RGBA bitmap.
        guard let ctx = CGContext(
            data: nil,
            width: g, height: g,
            bitsPerComponent: 8,
            bytesPerRow: g * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw StubEmbedderError.contextCreationFailed
        }

        ctx.draw(faceImage, in: CGRect(x: 0, y: 0, width: g, height: g))

        guard let pixelData = ctx.data else {
            throw StubEmbedderError.pixelReadFailed
        }
        let ptr = pixelData.bindMemory(to: UInt8.self, capacity: g * g * 4)

        // Convert to grayscale floats in [0, 1].
        var raw = [Float](repeating: 0, count: g * g)
        for i in 0..<(g * g) {
            let r = Float(ptr[i * 4])
            let green = Float(ptr[i * 4 + 1])
            let b = Float(ptr[i * 4 + 2])
            raw[i] = (0.299 * r + 0.587 * green + 0.114 * b) / 255.0
        }

        // Expand 64 → 128 with a deterministic non-linear transform.
        var values = [Float](repeating: 0, count: Self.outputDim)
        for i in 0..<(g * g) {
            values[i] = raw[i]
            values[i + g * g] = sin(Float(i + 1) * raw[i] * .pi)
        }

        // L2 normalize.
        let magnitude = sqrt(values.reduce(0) { $0 + $1 * $1 })
        if magnitude > 0 {
            for i in values.indices { values[i] /= magnitude }
        }

        return FaceEmbedding(values: values, isL2Normalized: true)
    }

    enum StubEmbedderError: Error {
        case contextCreationFailed
        case pixelReadFailed
    }
}
