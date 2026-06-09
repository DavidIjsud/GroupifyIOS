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

// MARK: - Text Index

/// Codable record for the OCR text manifest (`text_index.json`).
/// One per asset that contained recognizable text.
struct IndexedTextRecord: Codable, Sendable {
    let assetIdentifier: String
    let text: String
    let dateIndexed: Date
}

// MARK: - Scene Index (CLIP "describe the scene")

/// One CLIP image embedding for a whole photo asset (no faces involved).
/// Used by the semantic "describe the scene" search mode.
struct IndexedScene: Sendable {
    let assetIdentifier: String
    let embedding: [Float]   // 512 elements, L2-normalized
    let dateIndexed: Date
}

/// Lightweight Codable record for the scene manifest (`scene_index.json`).
/// The embedding itself lives in the binary blob; this stores its byte offset.
struct IndexedSceneRecord: Codable, Sendable {
    let assetIdentifier: String
    let dateIndexed: Date
    /// Byte offset into `scene_embeddings.bin` (index * embeddingDim * 4).
    let embeddingOffset: Int
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
