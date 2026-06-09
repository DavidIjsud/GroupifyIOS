import Foundation

/// Byte-level BPE tokenizer compatible with OpenAI CLIP / MobileCLIP text encoders.
///
/// This is a direct port of the reference `SimpleTokenizer`:
///  - `bytes_to_unicode()` maps raw UTF-8 bytes to a reversible unicode alphabet.
///  - The BPE merge table is read from `bpe_simple_vocab_16e6.txt` (the standard
///    CLIP vocab), using the canonical slice `merges[1 : 49152-256-2+1]`.
///  - The vocab is 49408 tokens: 256 byte chars, 256 with a `</w>` end-of-word
///    marker, the 48894 merged pairs, then `<|startoftext|>` (49406) and
///    `<|endoftext|>` (49407).
///  - `tokenize(_:)` returns a fixed 77-length context window (sot … eot, 0-padded).
///
/// Not thread-safe (mutable BPE cache). The owning embedder calls it inside its
/// serialization lock, so concurrent use never happens.
final class CLIPTokenizer {

    enum TokenizerError: Error, LocalizedError {
        case vocabNotFound
        case vocabUnreadable

        var errorDescription: String? {
            switch self {
            case .vocabNotFound:  return "CLIP BPE vocab (bpe_simple_vocab_16e6.txt) not found in bundle"
            case .vocabUnreadable: return "CLIP BPE vocab could not be read"
            }
        }
    }

    static let contextLength = 77
    /// Number of merge rules CLIP keeps: 49152 - 256 - 2 + 1 - 1 = 48894.
    private static let mergeCount = 48894

    private struct BytePair: Hashable { let first: String; let second: String }

    private let byteEncoder: [UInt8: String]
    private let encoder: [String: Int]
    private let bpeRanks: [BytePair: Int]
    private let startOfText: Int
    private let endOfText: Int
    private let pattern: NSRegularExpression

    private var cache: [String: String] = [
        "<|startoftext|>": "<|startoftext|>",
        "<|endoftext|>": "<|endoftext|>"
    ]

    // MARK: - Init

    /// Loads the vocab from the app bundle. Throws if the file is missing/unreadable.
    convenience init() throws {
        guard let url = Bundle.main.url(
            forResource: "bpe_simple_vocab_16e6", withExtension: "txt"
        ) else {
            throw TokenizerError.vocabNotFound
        }
        try self.init(vocabURL: url)
    }

    init(vocabURL: URL) throws {
        guard let raw = try? String(contentsOf: vocabURL, encoding: .utf8) else {
            throw TokenizerError.vocabUnreadable
        }

        // bytes_to_unicode(): build the reversible byte→char alphabet, preserving
        // the exact insertion order CLIP uses for the first 256 vocab entries.
        var byteList: [UInt8] = []
        var charList: [Int] = []   // unicode scalar values
        func addRange(_ lower: Int, _ upper: Int) {
            for v in lower...upper { byteList.append(UInt8(v)); charList.append(v) }
        }
        addRange(Int(Character("!").asciiValue!), Int(Character("~").asciiValue!)) // 33...126
        addRange(0xA1, 0xAC)  // ¡ … ¬
        addRange(0xAE, 0xFF)  // ® … ÿ
        var n = 0
        let present = Set(byteList)
        for b in 0...255 where !present.contains(UInt8(b)) {
            byteList.append(UInt8(b))
            charList.append(256 + n)
            n += 1
        }
        var byteEnc: [UInt8: String] = [:]
        var orderedByteChars: [String] = []
        for (i, b) in byteList.enumerated() {
            let s = String(UnicodeScalar(charList[i])!)
            byteEnc[b] = s
            orderedByteChars.append(s)
        }
        self.byteEncoder = byteEnc

        // Parse merges: skip line 0 (version header), keep the canonical slice.
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        var merges: [BytePair] = []
        merges.reserveCapacity(Self.mergeCount)
        let upper = min(1 + Self.mergeCount, lines.count)
        if lines.count > 1 {
            for idx in 1..<upper {
                let parts = lines[idx].split(separator: " ").map(String.init)
                guard parts.count == 2 else { continue }
                merges.append(BytePair(first: parts[0], second: parts[1]))
            }
        }

        var ranks: [BytePair: Int] = [:]
        ranks.reserveCapacity(merges.count)
        for (i, pair) in merges.enumerated() { ranks[pair] = i }
        self.bpeRanks = ranks

        // Build the vocab → id map in the exact CLIP order.
        var vocab: [String] = orderedByteChars                       // 256
        vocab.append(contentsOf: orderedByteChars.map { $0 + "</w>" }) // +256
        for pair in merges { vocab.append(pair.first + pair.second) }  // +48894
        vocab.append("<|startoftext|>")
        vocab.append("<|endoftext|>")

        var enc: [String: Int] = [:]
        enc.reserveCapacity(vocab.count)
        for (i, tok) in vocab.enumerated() { enc[tok] = i }
        self.encoder = enc
        self.startOfText = enc["<|startoftext|>"] ?? 49406
        self.endOfText = enc["<|endoftext|>"] ?? 49407

        // CLIP token regex: contractions, letter runs, single digits, symbol runs.
        let pat = "<\\|startoftext\\|>|<\\|endoftext\\|>|'s|'t|'re|'ve|'m|'ll|'d|[\\p{L}]+|[\\p{N}]|[^\\s\\p{L}\\p{N}]+"
        self.pattern = try NSRegularExpression(pattern: pat, options: [.caseInsensitive])
    }

    // MARK: - Public API

    /// Tokenizes one description into a fixed-length context window of token ids,
    /// matching CLIP's `tokenize()`: `[sot] + bpe(text) + [eot]`, truncated to
    /// `contextLength` (keeping a trailing eot) and 0-padded.
    func tokenize(_ text: String) -> [Int32] {
        var tokens = [startOfText] + encode(text) + [endOfText]
        if tokens.count > Self.contextLength {
            tokens = Array(tokens.prefix(Self.contextLength))
            tokens[Self.contextLength - 1] = endOfText
        }
        var result = [Int32](repeating: 0, count: Self.contextLength)
        for (i, t) in tokens.enumerated() { result[i] = Int32(t) }
        return result
    }

    // MARK: - Encoding

    private func encode(_ text: String) -> [Int] {
        let cleaned = whitespaceClean(text).lowercased()
        var bpeTokens: [Int] = []
        let ns = cleaned as NSString
        let matches = pattern.matches(in: cleaned, range: NSRange(location: 0, length: ns.length))
        for m in matches {
            let piece = ns.substring(with: m.range)
            // Translate each UTF-8 byte through the byte encoder.
            var translated = ""
            for b in Array(piece.utf8) {
                translated += byteEncoder[b] ?? ""
            }
            for token in bpe(translated).split(separator: " ") {
                if let id = encoder[String(token)] { bpeTokens.append(id) }
            }
        }
        return bpeTokens
    }

    // MARK: - BPE

    private func bpe(_ token: String) -> String {
        if let cached = cache[token] { return cached }

        // word = list of chars, with the last char carrying the </w> marker.
        var word = token.map { String($0) }
        guard !word.isEmpty else { return token }
        word[word.count - 1] = word[word.count - 1] + "</w>"

        if word.count == 1 {
            let result = word[0]
            cache[token] = result
            return result
        }

        while true {
            // Find the adjacent pair with the lowest merge rank.
            var bestPair: BytePair?
            var bestRank = Int.max
            for i in 0..<(word.count - 1) {
                let pair = BytePair(first: word[i], second: word[i + 1])
                if let rank = bpeRanks[pair], rank < bestRank {
                    bestRank = rank
                    bestPair = pair
                }
            }
            guard let pair = bestPair else { break }

            // Merge every occurrence of `pair` in one pass.
            var newWord: [String] = []
            var i = 0
            while i < word.count {
                if i < word.count - 1, word[i] == pair.first, word[i + 1] == pair.second {
                    newWord.append(pair.first + pair.second)
                    i += 2
                } else {
                    newWord.append(word[i])
                    i += 1
                }
            }
            word = newWord
            if word.count == 1 { break }
        }

        let result = word.joined(separator: " ")
        cache[token] = result
        return result
    }

    // MARK: - Text cleanup

    /// Collapses runs of whitespace and trims — a pragmatic stand-in for the
    /// reference `whitespace_clean` (ftfy/html unescaping is skipped; user queries
    /// rarely need it).
    private func whitespaceClean(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
