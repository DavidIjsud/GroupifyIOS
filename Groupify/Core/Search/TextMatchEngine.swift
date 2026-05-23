import Foundation

/// Matches a user's typed query against recognized photo text.
///
/// Strategy (mirrors the "substring + fuzzy" decision):
///  1. **Exact substring** — if the (normalized) document contains the whole
///     normalized query, it's a perfect match (score 1.0).
///  2. **Fuzzy** — otherwise, score each query token against the closest
///     document token using a Levenshtein similarity ratio, and average. This
///     tolerates OCR misreads and typos (e.g. "Smith" ↔ "Smyth").
///
/// Normalization lowercases, strips diacritics, and collapses whitespace so
/// matching is case/accent-insensitive and line-break agnostic.
enum TextMatchEngine {

    /// Default fuzzy cutoff: below this, a non-substring candidate is dropped.
    nonisolated static let defaultFuzzyThreshold: Float = 0.72

    nonisolated static func matches(
        query: String,
        records: [IndexedTextRecord],
        fuzzyThreshold: Float = defaultFuzzyThreshold
    ) -> [PhotoMatch] {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else { return [] }
        let queryTokens = tokenize(normalizedQuery)

        var results = [PhotoMatch]()
        for record in records {
            let doc = normalize(record.text)
            guard !doc.isEmpty else { continue }

            let score: Float
            if doc.contains(normalizedQuery) {
                score = 1.0
            } else {
                let candidate = fuzzyScore(queryTokens: queryTokens, docTokens: tokenize(doc))
                guard candidate >= fuzzyThreshold else { continue }
                score = candidate
            }

            results.append(PhotoMatch(
                assetIdentifier: record.assetIdentifier,
                similarityScore: score
            ))
        }

        return results.sorted { $0.similarityScore > $1.similarityScore }
    }

    // MARK: - Normalization

    /// Lowercase + diacritic-insensitive + whitespace-collapsed.
    nonisolated static func normalize(_ text: String) -> String {
        let folded = text.folding(
            options: [.diacriticInsensitive, .caseInsensitive],
            locale: Locale(identifier: "en_US")
        ).lowercased()
        return folded
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private nonisolated static func tokenize(_ normalized: String) -> [String] {
        normalized
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    // MARK: - Fuzzy scoring

    /// Average of each query token's best similarity to any document token.
    private nonisolated static func fuzzyScore(
        queryTokens: [String],
        docTokens: [String]
    ) -> Float {
        guard !queryTokens.isEmpty, !docTokens.isEmpty else { return 0 }

        var total: Float = 0
        for qToken in queryTokens {
            var best: Float = 0
            for dToken in docTokens {
                let sim = similarity(qToken, dToken)
                if sim > best {
                    best = sim
                    if best >= 1 { break }
                }
            }
            total += best
        }
        return total / Float(queryTokens.count)
    }

    /// Levenshtein similarity ratio in 0...1 (1 = identical).
    nonisolated static func similarity(_ a: String, _ b: String) -> Float {
        if a == b { return 1 }
        let maxLen = max(a.count, b.count)
        guard maxLen > 0 else { return 0 }
        let distance = levenshtein(Array(a), Array(b))
        return 1 - Float(distance) / Float(maxLen)
    }

    /// Classic two-row dynamic-programming edit distance.
    private nonisolated static func levenshtein(_ a: [Character], _ b: [Character]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }

        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,      // deletion
                    current[j - 1] + 1,   // insertion
                    previous[j - 1] + cost // substitution
                )
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }
}
