import Foundation

/// Creates the best available `FaceEmbedder` implementation.
///
/// - Default: `TFLiteFaceEmbedder` backed by `facenet.tflite`.
/// - Fallback: `StubFaceEmbedder` if the model file is missing from the bundle.
///
/// The `warningMessage` property is non-nil when falling back to the stub,
/// so the UI can inform the user that matching quality will be degraded.
enum FaceEmbedderFactory {

    struct Result {
        let embedder: any FaceEmbedder
        /// Non-nil if we fell back to the stub embedder.
        let warningMessage: String?
        /// Short identifier for the active embedder, e.g. "TFLite" or "Stub".
        let embedderName: String
    }

    nonisolated static func make() -> Result {
        if Bundle.main.path(forResource: "facenet", ofType: "tflite") != nil {
            return Result(
                embedder: TFLiteFaceEmbedder(),
                warningMessage: nil,
                embedderName: "TFLite"
            )
        } else {
            #if DEBUG
            print("[FaceEmbedderFactory] ⚠️ facenet.tflite not found in bundle — falling back to StubFaceEmbedder")
            #endif
            return Result(
                embedder: StubFaceEmbedder(),
                warningMessage: "FaceNet model not found. Using approximate matching (lower accuracy).",
                embedderName: "Stub"
            )
        }
    }
}
