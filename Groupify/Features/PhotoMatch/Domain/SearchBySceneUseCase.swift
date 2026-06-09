import Foundation

/// Searches the CLIP scene index for photos matching a free-text description.
/// Embeds the query text into the shared CLIP space, then ranks every indexed
/// scene by cosine similarity. Mirrors `SearchByTextUseCase`/`SearchByPhotoUseCase`.
struct SearchBySceneUseCase: Sendable {
    let embedder: any SceneEmbedder
    let repository: any SceneIndexRepository

    enum SearchError: Error, LocalizedError {
        case emptyQuery

        var errorDescription: String? {
            switch self {
            case .emptyQuery: return L10n.enterSceneDescription
            }
        }
    }

    nonisolated func execute(
        description: String,
        threshold: Float
    ) async throws -> [PhotoMatch] {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SearchError.emptyQuery
        }

        // 1. Embed the query text into the CLIP space (L2-normalized).
        let queryVector = try await embedder.embedText(trimmed)

        // 2. Load the scene index and rank by cosine similarity.
        let index = try await repository.load()

        return EmbeddingSearchEngine.sceneMatchesAboveThreshold(
            queryVector: queryVector,
            indexedScenes: index,
            threshold: threshold
        )
    }
}
