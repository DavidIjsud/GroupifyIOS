import CoreGraphics
import CoreML
import CoreVideo
import Foundation

/// Real CLIP scene embedder backed by the MobileCLIP Core ML models
/// (`mobileclip_s0_image.mlmodelc` + `mobileclip_s0_text.mlmodelc`).
///
/// - Image side: the model takes an image input ("image") with normalization
///   baked in; we just hand it a pixel buffer sized to the model's own declared
///   input dimensions, read at runtime (no hardcoded 256).
/// - Text side: the query is tokenized with `CLIPTokenizer` into a [1, 77] Int32
///   array ("text").
/// - Both produce `final_emb_1`; we L2-normalize so a vDSP dot product equals
///   cosine similarity (same contract as the face path).
///
/// Thread safety: `MLModel` prediction is serialized through an `NSLock` inside a
/// `@unchecked Sendable` holder, mirroring `TFLiteFaceEmbedder`.
struct CoreMLSceneEmbedder: SceneEmbedder, Sendable {

    private nonisolated static var imageModelName: String { MobileCLIPConfig.imageModelName }
    private nonisolated static var textModelName:  String { MobileCLIPConfig.textModelName }
    private nonisolated static let outputFeature  = "final_emb_1"

    enum SceneEmbedderError: Error, LocalizedError {
        case modelNotFound(String)
        case modelLoadFailed(String)
        case pixelBufferCreationFailed
        case inferenceFailed(String)
        case missingOutput

        nonisolated var errorDescription: String? {
            switch self {
            case .modelNotFound(let n):   return "MobileCLIP model not found in bundle: \(n)"
            case .modelLoadFailed(let d): return "Failed to load MobileCLIP model: \(d)"
            case .pixelBufferCreationFailed: return "Failed to build pixel buffer for CLIP image input"
            case .inferenceFailed(let d): return "CLIP inference failed: \(d)"
            case .missingOutput:          return "CLIP model returned no embedding"
            }
        }
    }

    // MARK: - Model holder (lazy load + serialization)

    private final class ModelHolder: @unchecked Sendable {
        private let lock = NSLock()
        private nonisolated(unsafe) var imageModel: MLModel?
        private nonisolated(unsafe) var textModel: MLModel?
        private nonisolated(unsafe) var tokenizer: CLIPTokenizer?
        private nonisolated(unsafe) var imageInputName: String?
        private nonisolated(unsafe) var textInputName: String?
        private nonisolated(unsafe) var imageWidth = 256
        private nonisolated(unsafe) var imageHeight = 256

        func withImage<T>(_ body: (MLModel, String, Int, Int) throws -> T) throws -> T {
            lock.lock(); defer { lock.unlock() }
            if imageModel == nil { try loadImage() }
            return try body(imageModel!, imageInputName!, imageWidth, imageHeight)
        }

        func withText<T>(_ body: (MLModel, String, CLIPTokenizer) throws -> T) throws -> T {
            lock.lock(); defer { lock.unlock() }
            if textModel == nil { try loadText() }
            return try body(textModel!, textInputName!, tokenizer!)
        }

        private func loadImage() throws {
            let model = try Self.loadModel(named: imageModelName)
            self.imageModel = model
            let inputs = model.modelDescription.inputDescriptionsByName
            let name = inputs["image"] != nil ? "image" : (inputs.keys.first ?? "image")
            self.imageInputName = name
            if let constraint = inputs[name]?.imageConstraint {
                self.imageWidth = constraint.pixelsWide
                self.imageHeight = constraint.pixelsHigh
            }
        }

        private func loadText() throws {
            let model = try Self.loadModel(named: textModelName)
            self.textModel = model
            let inputs = model.modelDescription.inputDescriptionsByName
            self.textInputName = inputs["text"] != nil ? "text" : (inputs.keys.first ?? "text")
            self.tokenizer = try CLIPTokenizer()
        }

        private static func loadModel(named name: String) throws -> MLModel {
            guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") else {
                throw SceneEmbedderError.modelNotFound(name)
            }
            do {
                let config = MLModelConfiguration()
                config.computeUnits = .all
                return try MLModel(contentsOf: url, configuration: config)
            } catch {
                throw SceneEmbedderError.modelLoadFailed(error.localizedDescription)
            }
        }
    }

    private let holder = ModelHolder()

    // MARK: - SceneEmbedder

    nonisolated func embedImage(_ image: CGImage) async throws -> [Float] {
        let values: [Float] = try holder.withImage { model, inputName, width, height in
            guard let buffer = Self.makePixelBuffer(from: image, width: width, height: height) else {
                throw SceneEmbedderError.pixelBufferCreationFailed
            }
            let provider = try MLDictionaryFeatureProvider(
                dictionary: [inputName: MLFeatureValue(pixelBuffer: buffer)]
            )
            return try Self.runEmbedding(model: model, provider: provider)
        }
        return values
    }

    nonisolated func embedText(_ text: String) async throws -> [Float] {
        let values: [Float] = try holder.withText { model, inputName, tokenizer in
            let tokens = tokenizer.tokenize(text)
            let array = try MLMultiArray(
                shape: [1, NSNumber(value: CLIPTokenizer.contextLength)],
                dataType: .int32
            )
            for (i, token) in tokens.enumerated() {
                array[i] = NSNumber(value: token)
            }
            let provider = try MLDictionaryFeatureProvider(
                dictionary: [inputName: MLFeatureValue(multiArray: array)]
            )
            return try Self.runEmbedding(model: model, provider: provider)
        }
        return values
    }

    // MARK: - Inference helpers

    private nonisolated static func runEmbedding(
        model: MLModel, provider: MLFeatureProvider
    ) throws -> [Float] {
        let output: MLFeatureProvider
        do {
            output = try model.prediction(from: provider)
        } catch {
            throw SceneEmbedderError.inferenceFailed(error.localizedDescription)
        }

        let outName = output.featureValue(for: outputFeature)?.multiArrayValue != nil
            ? outputFeature
            : (output.featureNames.first ?? outputFeature)

        guard let multiArray = output.featureValue(for: outName)?.multiArrayValue else {
            throw SceneEmbedderError.missingOutput
        }

        let count = multiArray.count
        var values = [Float](repeating: 0, count: count)
        for i in 0..<count { values[i] = multiArray[i].floatValue }

        // L2-normalize so dot product == cosine similarity.
        let magnitude = sqrt(values.reduce(0) { $0 + $1 * $1 })
        if magnitude > 0 {
            for i in values.indices { values[i] /= magnitude }
        }
        return values
    }

    /// Renders a CGImage into a fresh 32ARGB pixel buffer of the model's expected
    /// size. Core ML converts to the model's colorspace and applies the baked-in
    /// normalization.
    private nonisolated static func makePixelBuffer(
        from image: CGImage, width: Int, height: Int
    ) -> CVPixelBuffer? {
        let attrs: CFDictionary = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ] as CFDictionary

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height,
            kCVPixelFormatType_32ARGB, attrs, &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width, height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }

        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
}
