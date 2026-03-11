import Accelerate
import Foundation

/// Performs fast cosine-similarity search over L2-normalized face embeddings
/// using Accelerate vDSP for dot products and a Top-K min-heap to avoid
/// sorting the full result set.
enum EmbeddingSearchEngine {

    /// Returns the top matches for a set of query embeddings against the index.
    /// For each indexed photo (asset), the best similarity across all query vectors
    /// and all faces in that asset is kept.
    ///
    /// `kPerFace` controls how many results per query face are retained. The total
    /// cap is `kPerFace × queryVectors.count`, ensuring each selected face gets
    /// fair representation in the final results.
    ///
    /// - Complexity: O(N·Q) where N = index size, Q = query count.
    nonisolated static func topKMatches(
        queryVectors: [[Float]],
        indexedFaces: [IndexedFace],
        kPerFace: Int = 75
    ) -> [PhotoMatch] {
        guard !queryVectors.isEmpty, !indexedFaces.isEmpty else { return [] }

        let queryCount = queryVectors.count

        #if DEBUG
        print("[EmbeddingSearchEngine] Query faces: \(queryCount), indexed faces: \(indexedFaces.count)")
        #endif

        // Phase 1: Compute best score per asset PER query face.
        // This ensures each query face contributes its own top matches.
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

        // Phase 3: Top-K selection — scale K by number of query faces.
        let totalK = kPerFace * queryCount
        var heap = MinHeap(capacity: totalK)
        for (assetId, score) in mergedScores {
            heap.insert(assetId: assetId, score: score)
        }

        let results = heap.extractSortedDescending()

        #if DEBUG
        print("[EmbeddingSearchEngine] Final results: \(results.count) (cap: \(totalK))")
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

// MARK: - Min-Heap for Top-K

/// A fixed-capacity min-heap that keeps the top K elements by score.
/// Insert is O(log K). Total selection from N elements is O(N log K).
private struct MinHeap {
    private struct Entry {
        let assetId: String
        let score: Float
    }

    private var storage: [Entry]
    private let capacity: Int

    init(capacity: Int) {
        self.capacity = max(capacity, 1)
        self.storage = []
        self.storage.reserveCapacity(capacity + 1)
    }

    mutating func insert(assetId: String, score: Float) {
        let entry = Entry(assetId: assetId, score: score)
        if storage.count < capacity {
            storage.append(entry)
            siftUp(storage.count - 1)
        } else if score > storage[0].score {
            // Replace the minimum element.
            storage[0] = entry
            siftDown(0)
        }
    }

    /// Returns all entries sorted by score descending.
    mutating func extractSortedDescending() -> [PhotoMatch] {
        // The heap is small (≤ K), so a simple sort is fine.
        storage.sort { $0.score > $1.score }
        return storage.map {
            PhotoMatch(assetIdentifier: $0.assetId, similarityScore: $0.score)
        }
    }

    // MARK: - Heap Operations

    private mutating func siftUp(_ index: Int) {
        var i = index
        while i > 0 {
            let parent = (i - 1) / 2
            if storage[i].score < storage[parent].score {
                storage.swapAt(i, parent)
                i = parent
            } else {
                break
            }
        }
    }

    private mutating func siftDown(_ index: Int) {
        var i = index
        let count = storage.count
        while true {
            let left = 2 * i + 1
            let right = 2 * i + 2
            var smallest = i
            if left < count && storage[left].score < storage[smallest].score {
                smallest = left
            }
            if right < count && storage[right].score < storage[smallest].score {
                smallest = right
            }
            if smallest == i { break }
            storage.swapAt(i, smallest)
            i = smallest
        }
    }
}
