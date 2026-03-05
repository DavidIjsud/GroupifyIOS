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

// MARK: - Index Persistence

protocol FaceIndexRepository: Sendable {
    nonisolated func load() async throws -> [IndexedFace]
    nonisolated func loadRecords() async throws -> [IndexedFaceRecord]
    nonisolated func save(_ faces: [IndexedFace]) async throws
    nonisolated func append(newFaces: [IndexedFace]) async throws
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
    /// Loads a full-resolution image.
    nonisolated func loadFullImage(for asset: PHAsset) async throws -> UIImage
    /// Exports images to temp JPEG files for sharing. Returns file URLs.
    nonisolated func exportForSharing(assetIdentifiers: [String]) async throws -> [URL]
}
