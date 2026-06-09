import Foundation

/// Creates the best available `SceneEmbedder` for "describe the scene" search.
///
/// - Default: `CoreMLSceneEmbedder` backed by the MobileCLIP Core ML models,
///   but only when BOTH compiled models AND the BPE vocab are in the bundle.
/// - Fallback: `StubSceneEmbedder` if any of those resources are missing.
///
/// The `warningMessage` is non-nil when falling back, so the UI can tell the user
/// scene matching is degraded. Mirrors `FaceEmbedderFactory`.
enum SceneEmbedderFactory {

    struct Result {
        let embedder: any SceneEmbedder
        /// Non-nil if we fell back to the stub embedder.
        let warningMessage: String?
        /// Short identifier for the active embedder, e.g. "CoreML" or "Stub".
        let embedderName: String
        /// Identifies the vector space the index will be built in. Switching this
        /// (e.g. swapping s0→s2, or stub→real) triggers a one-time index rebuild.
        let modelId: String
    }

    nonisolated static func make() -> Result {
        let hasImageModel = Bundle.main.url(forResource: MobileCLIPConfig.imageModelName, withExtension: "mlmodelc") != nil
        let hasTextModel  = Bundle.main.url(forResource: MobileCLIPConfig.textModelName, withExtension: "mlmodelc") != nil
        let hasVocab      = Bundle.main.url(forResource: "bpe_simple_vocab_16e6", withExtension: "txt") != nil

        if hasImageModel && hasTextModel && hasVocab {
            return Result(
                embedder: CoreMLSceneEmbedder(),
                warningMessage: nil,
                embedderName: "CoreML",
                modelId: MobileCLIPConfig.indexModelId
            )
        }

        #if DEBUG
        print("[SceneEmbedderFactory] ⚠️ MobileCLIP resources missing (image: \(hasImageModel), text: \(hasTextModel), vocab: \(hasVocab)) — falling back to StubSceneEmbedder")
        #endif
        return Result(
            embedder: StubSceneEmbedder(),
            warningMessage: L10n.sceneModelMissingWarning,
            embedderName: "Stub",
            modelId: "stub"
        )
    }
}
