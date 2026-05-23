import Foundation

/// Stores recognized photo text in Application Support / GroupifyIndex/`text_index.json`,
/// alongside the face index. JSON-only (no binary blob) — one record per asset
/// that contained text, deduped by `assetIdentifier`. New records are appended
/// (the whole manifest is rewritten atomically), mirroring the face-index manifest.
struct FileTextIndexRepository: TextIndexRepository, Sendable {
    private nonisolated static let dirName = "GroupifyIndex"
    private nonisolated static let jsonFile = "text_index.json"

    // MARK: - TextIndexRepository

    nonisolated func loadRecords() async throws -> [IndexedTextRecord] {
        let jsonURL = try storageURL()
        let fm = FileManager.default
        guard fm.fileExists(atPath: jsonURL.path) else { return [] }

        do {
            let jsonData = try Data(contentsOf: jsonURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([IndexedTextRecord].self, from: jsonData)
        } catch {
            // Corrupted manifest — fall back to empty index.
            return []
        }
    }

    nonisolated func append(newRecords: [IndexedTextRecord]) async throws {
        guard !newRecords.isEmpty else { return }
        let jsonURL = try storageURL(createDir: true)

        let existing = (try? await loadRecords()) ?? []
        let existingIds = Set(existing.map(\.assetIdentifier))

        // Only append records for assets not already in the index.
        let toAdd = newRecords.filter { !existingIds.contains($0.assetIdentifier) }
        guard !toAdd.isEmpty else { return }

        let allRecords = existing + toAdd
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(allRecords)
        try jsonData.write(to: jsonURL, options: .atomic)
    }

    nonisolated func clear() async throws {
        let jsonURL = try storageURL()
        let fm = FileManager.default
        if fm.fileExists(atPath: jsonURL.path) {
            try fm.removeItem(at: jsonURL)
        }
    }

    // MARK: - Private

    private nonisolated func storageURL(createDir: Bool = false) throws -> URL {
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
        return dir.appendingPathComponent(Self.jsonFile)
    }
}
