import Foundation

/// Stores groups as a single JSON file in Application Support / `GroupifyGroups/groups.json`,
/// mirroring the approach of `FileFaceIndexRepository`. Photos are referenced by
/// asset identifier only; the library is never modified.
struct FilePhotoGroupRepository: PhotoGroupRepository, Sendable {
    private nonisolated static let dirName = "GroupifyGroups"
    private nonisolated static let fileName = "groups.json"

    // MARK: - PhotoGroupRepository

    nonisolated func loadGroups() async throws -> [PhotoGroup] {
        let url = try storageURL()
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return [] }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([PhotoGroup].self, from: data)
        } catch {
            // Corrupted manifest — fall back to empty rather than crashing.
            return []
        }
    }

    nonisolated func saveAll(_ groups: [PhotoGroup]) async throws {
        let url = try storageURL(createDir: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(groups)
        try data.write(to: url, options: .atomic)
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
        return dir.appendingPathComponent(Self.fileName)
    }
}
