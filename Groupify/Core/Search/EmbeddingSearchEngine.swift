import Accelerate
import Foundation

/// Performs fast cosine-similarity search over L2-normalized face embeddings
/// using Accelerate vDSP for dot products. Returns all matches above a
/// minimum similarity threshold, sorted by score descending.
enum EmbeddingSearchEngine {

    /// Returns all matches whose best similarity score meets the threshold.
    ///
    /// For each indexed photo (asset), the best similarity across all query
    /// vectors and all faces in that asset is kept. Results are sorted by
    /// score descending so the UI can page through them in order.
    ///
    /// - Parameters:
    ///   - queryVectors: Embedding vectors for each selected query face.
    ///   - indexedFaces: The full face index loaded from disk.
    ///   - threshold: Minimum similarity score (0…1) to include a result.
    /// - Complexity: O(N·Q) where N = index size, Q = query count.
    nonisolated static func matchesAboveThreshold(
        queryVectors: [[Float]],
        indexedFaces: [IndexedFace],
        threshold: Float
    ) -> [PhotoMatch] {
        guard !queryVectors.isEmpty, !indexedFaces.isEmpty else { return [] }

        let queryCount = queryVectors.count

        #if DEBUG
        print("[EmbeddingSearchEngine] Query faces: \(queryCount), indexed faces: \(indexedFaces.count), threshold: \(threshold)")
        #endif

        // Phase 1: Compute best score per asset PER query face.
        var perFaceScores = [[String: Float]](repeating: [:], count: queryCount)

        for indexed in indexedFaces {
            let iVec = indexed.embedding.values
            for (qIdx, qVec) in queryVectors.enumerated() {
                let score = max(0, vDSPDotProduct(qVec, iVec))
                let assetId = indexed.assetIdentifier
                if let existing = perFaceScores[qIdx][assetId] {
                    if score > existing {
                        perFaceScores[qIdx][assetId] = score
                    }
                } else {
                    perFaceScores[qIdx][assetId] = score
                }
            }
        }

        #if DEBUG
        for (qIdx, scores) in perFaceScores.enumerated() {
            let nonZero = scores.values.filter { $0 > 0 }.count
            print("[EmbeddingSearchEngine]   Face \(qIdx): \(nonZero) assets with score > 0")
        }
        #endif

        // Phase 2: Merge — for each asset, keep the best score across all faces.
        var mergedScores = [String: Float]()
        for faceScores in perFaceScores {
            for (assetId, score) in faceScores {
                if let existing = mergedScores[assetId] {
                    if score > existing {
                        mergedScores[assetId] = score
                    }
                } else {
                    mergedScores[assetId] = score
                }
            }
        }

        #if DEBUG
        print("[EmbeddingSearchEngine] Merged unique assets: \(mergedScores.count)")
        #endif

        // Phase 3: Filter by threshold and sort descending.
        var results = [PhotoMatch]()
        results.reserveCapacity(mergedScores.count / 2)
        for (assetId, score) in mergedScores where score >= threshold {
            results.append(PhotoMatch(assetIdentifier: assetId, similarityScore: score))
        }
        results.sort { $0.similarityScore > $1.similarityScore }

        #if DEBUG
        print("[EmbeddingSearchEngine] Results above threshold: \(results.count)")
        #endif

        return results
    }

    // MARK: - vDSP Dot Product

    /// Computes dot product of two Float arrays using Accelerate.
    /// For L2-normalized vectors this equals cosine similarity.
    private nonisolated static func vDSPDotProduct(
        _ a: [Float], _ b: [Float]
    ) -> Float {
        let count = min(a.count, b.count)
        guard count > 0 else { return 0 }
        var result: Float = 0
        a.withUnsafeBufferPointer { aPtr in
            b.withUnsafeBufferPointer { bPtr in
                vDSP_dotpr(
                    aPtr.baseAddress!, 1,
                    bPtr.baseAddress!, 1,
                    &result,
                    vDSP_Length(count)
                )
            }
        }
        return result
    }
}
