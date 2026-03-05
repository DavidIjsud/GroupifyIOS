import Foundation

// MARK: - Face Detection

/// Normalized bounding box with top-left origin. All values in 0...1.
struct FaceBoundingBox: Codable, Sendable {
    let x: Float
    let y: Float
    let width: Float
    let height: Float

    nonisolated var area: Float { width * height }
}

struct DetectedFace: Sendable {
    let boundingBox: FaceBoundingBox
    let confidence: Float
}

// MARK: - Embeddings

struct FaceEmbedding: Sendable {
    let values: [Float]       // 128 elements
    let isL2Normalized: Bool
}

// MARK: - Index

struct IndexedFace: Sendable {
    let assetIdentifier: String
    let faceIndexInAsset: Int
    let boundingBox: FaceBoundingBox
    let embedding: FaceEmbedding
    let dateIndexed: Date
}

/// Lightweight Codable record for the JSON manifest (embedding stored in binary).
struct IndexedFaceRecord: Codable, Sendable {
    let assetIdentifier: String
    let faceIndexInAsset: Int
    let boundingBox: FaceBoundingBox
    let dateIndexed: Date
    /// Byte offset into the embeddings.bin file (index * embeddingDim * 4).
    let embeddingOffset: Int

    /// Unique key for deduplication: "assetIdentifier#faceIndex".
    nonisolated var dedupeKey: String {
        "\(assetIdentifier)#\(faceIndexInAsset)"
    }
}

// MARK: - Query Faces

struct QueryFace: Sendable {
    let id: Int
    let boundingBox: FaceBoundingBox
}

// MARK: - Search Results

struct PhotoMatch: Sendable {
    let assetIdentifier: String
    let similarityScore: Float  // 0...1
}
