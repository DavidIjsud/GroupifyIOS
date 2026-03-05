import CoreGraphics
import Foundation
import TensorFlowLiteSwift
import UIKit

/// Real FaceNet embedder backed by a TensorFlow Lite `.tflite` model.
///
/// Thread safety: `Interpreter` is NOT thread-safe. All inference is serialised
/// through an internal `NSLock`. The struct itself is `Sendable` because the
/// lock + interpreter live behind a class-based holder with `@unchecked Sendable`.
struct TFLiteFaceEmbedder: FaceEmbedder, Sendable {

    // MARK: - Constants

    private nonisolated static let inputSize = 160        // 160×160 RGB
    private nonisolated static let channels  = 3
    private nonisolated static let expectedEmbeddingDim = 128

    // MARK: - Errors

    enum TFLiteEmbedderError: Error, LocalizedError {
        case modelNotFound
        case interpreterCreationFailed(String)
        case preprocessingFailed
        case inferenceFailed(String)
        case unexpectedOutputShape(Int)

        nonisolated var errorDescription: String? {
            switch self {
            case .modelNotFound:
                return "FaceNet model file not found in app bundle"
            case .interpreterCreationFailed(let detail):
                return "Failed to create TFLite interpreter: \(detail)"
            case .preprocessingFailed:
                return "Failed to preprocess face image for inference"
            case .inferenceFailed(let detail):
                return "Face embedding inference failed: \(detail)"
            case .unexpectedOutputShape(let got):
                return "Unexpected embedding dimension: expected \(TFLiteFaceEmbedder.expectedEmbeddingDim), got \(got)"
            }
        }
    }

    // MARK: - Interpreter holder (class for reference semantics + lock)

    /// Holds the TFLite `Interpreter` behind a lock so that concurrent calls
    /// from different async tasks are serialised.
    private final class InterpreterHolder: @unchecked Sendable {
        private let lock = NSLock()
        private nonisolated(unsafe) var interpreter: Interpreter?
        private nonisolated(unsafe) var isAllocated = false

        /// Lazily creates the interpreter on first use.
        nonisolated func withInterpreter<T>(_ body: (Interpreter) throws -> T) throws -> T {
            lock.lock()
            defer { lock.unlock() }

            if interpreter == nil {
                guard let modelPath = Bundle.main.path(
                    forResource: "facenet", ofType: "tflite"
                ) else {
                    throw TFLiteEmbedderError.modelNotFound
                }

                do {
                    var options = Interpreter.Options()
                    options.threadCount = 2
                    let interp = try Interpreter(modelPath: modelPath, options: options)
                    try interp.allocateTensors()
                    self.interpreter = interp
                    self.isAllocated = true
                } catch {
                    throw TFLiteEmbedderError.interpreterCreationFailed(error.localizedDescription)
                }
            }

            return try body(interpreter!)
        }
    }

    private let holder = InterpreterHolder()

    // MARK: - FaceEmbedder conformance

    nonisolated func computeEmbedding(faceImage: CGImage) async throws -> FaceEmbedding {
        let inputData = try preprocess(faceImage)
        let outputData: Data = try holder.withInterpreter { interpreter in
            try interpreter.copy(inputData, toInputAt: 0)
            try interpreter.invoke()
            let outputTensor = try interpreter.output(at: 0)
            return outputTensor.data
        }

        // Parse output floats.
        let floatCount = outputData.count / MemoryLayout<Float32>.size
        guard floatCount == Self.expectedEmbeddingDim else {
            throw TFLiteEmbedderError.unexpectedOutputShape(floatCount)
        }

        var values = [Float](repeating: 0, count: floatCount)
        _ = values.withUnsafeMutableBytes { outputData.copyBytes(to: $0) }

        // L2-normalize.
        let magnitude = sqrt(values.reduce(0) { $0 + $1 * $1 })
        if magnitude > 0 {
            for i in values.indices { values[i] /= magnitude }
        }

        return FaceEmbedding(values: values, isL2Normalized: true)
    }

    // MARK: - Preprocessing

    /// Resizes the face CGImage to 160×160, converts to RGB Float32,
    /// and normalizes each channel with `(pixel - 127.5) / 127.5`.
    /// Returns raw bytes ready for the TFLite input tensor.
    private nonisolated func preprocess(_ faceImage: CGImage) throws -> Data {
        let size = Self.inputSize
        let bytesPerRow = size * 4 // RGBA

        guard let ctx = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            throw TFLiteEmbedderError.preprocessingFailed
        }

        // Draw the face image scaled to 160×160.
        ctx.interpolationQuality = .high
        ctx.draw(faceImage, in: CGRect(x: 0, y: 0, width: size, height: size))

        guard let pixelData = ctx.data else {
            throw TFLiteEmbedderError.preprocessingFailed
        }

        let ptr = pixelData.bindMemory(to: UInt8.self, capacity: size * size * 4)

        // Build Float32 buffer: [1, 160, 160, 3] = 160*160*3 floats.
        let floatCount = size * size * Self.channels
        var floatBuffer = [Float32](repeating: 0, count: floatCount)

        for pixel in 0..<(size * size) {
            let r = Float32(ptr[pixel * 4])
            let g = Float32(ptr[pixel * 4 + 1])
            let b = Float32(ptr[pixel * 4 + 2])

            floatBuffer[pixel * 3]     = (r - 127.5) / 127.5
            floatBuffer[pixel * 3 + 1] = (g - 127.5) / 127.5
            floatBuffer[pixel * 3 + 2] = (b - 127.5) / 127.5
        }

        return floatBuffer.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
