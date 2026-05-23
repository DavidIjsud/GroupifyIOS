import Foundation

/// Persists lightweight indexing metadata (e.g. last-indexed timestamp)
/// as a JSON file alongside the face index in Application Support/GroupifyIndex/.
struct IndexMetadataStore: Sendable {
    private nonisolated static let dirName = "GroupifyIndex"
    private nonisolated static let fileName = "index_metadata.json"

    private struct Metadata: Codable {
        var lastIndexedAt: Date?
        /// Last-indexed timestamp for the OCR text index (independent of faces).
        var lastTextIndexedAt: Date?
    }

    // MARK: - Public — Face index

    nonisolated func loadLastIndexedDate() -> Date? {
        loadMetadata()?.lastIndexedAt
    }

    nonisolated func saveLastIndexedDate(_ date: Date) throws {
        var metadata = loadMetadata() ?? Metadata()
        metadata.lastIndexedAt = date
        try write(metadata)
    }

    // MARK: - Public — Text (OCR) index

    nonisolated func loadLastTextIndexedDate() -> Date? {
        loadMetadata()?.lastTextIndexedAt
    }

    nonisolated func saveLastTextIndexedDate(_ date: Date) throws {
        var metadata = loadMetadata() ?? Metadata()
        metadata.lastTextIndexedAt = date
        try write(metadata)
    }

    nonisolated func clear() throws {
        guard let url = try? fileURL(),
              FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - Private

    private nonisolated func loadMetadata() -> Metadata? {
        guard let url = try? fileURL(),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Metadata.self, from: data)
        } catch {
            return nil
        }
    }

    private nonisolated func write(_ metadata: Metadata) throws {
        let url = try fileURL(createDir: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(metadata)
        try data.write(to: url, options: .atomic)
    }

    private nonisolated func fileURL(createDir: Bool = false) throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = appSupport.appendingPathComponent(Self.dirName, isDirectory: true)
        if createDir && !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(Self.fileName)
    }
}
