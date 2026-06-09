import CoreGraphics
import Photos
import UIKit

// MARK: - Face Detection

protocol FaceDetector: Sendable {
    nonisolated func detectFaces(in image: UIImage) async throws -> [DetectedFace]
}

// MARK: - Face Embedding

protocol FaceEmbedder: Sendable {
    nonisolated func computeEmbedding(faceImage: CGImage) async throws -> FaceEmbedding
}

// MARK: - Text Recognition (OCR)

/// Reads the visible printed/handwritten text in an image, on-device.
/// Mirrors `FaceDetector`: implementations normalize internally and return the
/// recognized text joined into a single string (newline-separated lines).
protocol TextRecognizer: Sendable {
    nonisolated func recognizeText(in image: UIImage) async throws -> String
}

// MARK: - Scene Embedding (CLIP)

/// Produces CLIP-style embeddings for semantic ("describe the scene") search.
/// Both methods return L2-normalized vectors of the *same* dimension, so an
/// image vector and a text vector can be compared by cosine similarity (a vDSP
/// dot product, exactly like the face path).
protocol SceneEmbedder: Sendable {
    /// Embeds a photo (or its thumbnail) into the shared CLIP space.
    nonisolated func embedImage(_ image: CGImage) async throws -> [Float]
    /// Embeds a free-text description into the shared CLIP space.
    nonisolated func embedText(_ text: String) async throws -> [Float]
}

// MARK: - Index Persistence

protocol FaceIndexRepository: Sendable {
    nonisolated func load() async throws -> [IndexedFace]
    nonisolated func loadRecords() async throws -> [IndexedFaceRecord]
    nonisolated func save(_ faces: [IndexedFace]) async throws
    nonisolated func append(newFaces: [IndexedFace]) async throws
    nonisolated func clear() async throws
}

// MARK: - Photo Groups Persistence

/// Persists user-created groups of matched photos (local reference store).
/// Implementations rewrite the whole collection on save — groups are small
/// (a name plus a list of asset identifiers), mirroring the face-index manifest.
protocol PhotoGroupRepository: Sendable {
    nonisolated func loadGroups() async throws -> [PhotoGroup]
    nonisolated func saveAll(_ groups: [PhotoGroup]) async throws
}

// MARK: - Text Index Persistence

/// Persists recognized text per photo asset (local reference store).
/// Simpler than the face index — no binary embedding blob, just a JSON manifest
/// of `assetIdentifier → recognized text`, deduped by `assetIdentifier`.
protocol TextIndexRepository: Sendable {
    nonisolated func loadRecords() async throws -> [IndexedTextRecord]
    nonisolated func append(newRecords: [IndexedTextRecord]) async throws
    nonisolated func clear() async throws
}

// MARK: - Scene Index Persistence

/// Persists one CLIP image embedding per photo asset, deduped by `assetIdentifier`.
/// Mirrors `FaceIndexRepository` (binary blob + JSON manifest) but stores one
/// vector per asset instead of one per face.
protocol SceneIndexRepository: Sendable {
    nonisolated func load() async throws -> [IndexedScene]
    nonisolated func loadRecords() async throws -> [IndexedSceneRecord]
    nonisolated func append(newScenes: [IndexedScene]) async throws
    nonisolated func clear() async throws
}

// MARK: - Photo Library Access

protocol PhotoLibraryService: Sendable {
    /// Requests read-write authorization. Returns the final status.
    nonisolated func requestAuthorization() async -> PHAuthorizationStatus
    /// Returns all photo assets (images) ordered by creation date descending.
    nonisolated func fetchAllAssets() -> [PHAsset]
    /// Returns photo assets created or modified after the given date. If nil, returns all.
    nonisolated func fetchAssets(newerThan date: Date?) -> [PHAsset]
    /// Loads a thumbnail for indexing.
    nonisolated func loadThumbnail(for asset: PHAsset, targetSize: CGSize) async throws -> UIImage
    /// Loads a higher-quality (exact-resized) thumbnail. Used for OCR, where the
    /// fast/degraded thumbnail would lose small text.
    nonisolated func loadHighQualityThumbnail(for asset: PHAsset, targetSize: CGSize) async throws -> UIImage
    /// Loads a full-resolution image.
    nonisolated func loadFullImage(for asset: PHAsset) async throws -> UIImage
    /// Exports images to temp JPEG files for sharing. Returns file URLs.
    nonisolated func exportForSharing(assetIdentifiers: [String]) async throws -> [URL]
}
