import Foundation

/// Searches the OCR text index for photos whose recognized text contains the
/// query (exact substring) or closely matches it (fuzzy). Returns matches
/// sorted by relevance descending. Mirrors `SearchByPhotoUseCase`.
struct SearchByTextUseCase: Sendable {
    let repository: any TextIndexRepository

    enum SearchError: Error, LocalizedError {
        case emptyQuery

        var errorDescription: String? {
            switch self {
            case .emptyQuery: return L10n.enterSearchText
            }
        }
    }

    nonisolated func execute(
        query: String,
        fuzzyThreshold: Float = TextMatchEngine.defaultFuzzyThreshold
    ) async throws -> [PhotoMatch] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SearchError.emptyQuery
        }

        let records = try await repository.loadRecords()
        return TextMatchEngine.matches(
            query: trimmed,
            records: records,
            fuzzyThreshold: fuzzyThreshold
        )
    }
}
