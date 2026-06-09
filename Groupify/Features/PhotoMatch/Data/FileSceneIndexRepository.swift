import Foundation

/// Stores CLIP scene embeddings in Application Support / GroupifyIndex/, alongside
/// the face index. One Float32 vector per asset:
/// - `scene_index.json` — manifest: `assetIdentifier` + byte offset per scene.
/// - `scene_embeddings.bin` — contiguous Float32 vectors (512 dims × 4 = 2048 bytes each).
///
/// New scenes are appended (binary via `FileHandle`, JSON rewritten atomically),
/// deduped by `assetIdentifier`. Mirrors `FileFaceIndexRepository`.
struct FileSceneIndexRepository: SceneIndexRepository, Sendable {
    private nonisolated static let dirName = "GroupifyIndex"
    private nonisolated static let jsonFile = "scene_index.json"
    private nonisolated static let binFile  = "scene_embeddings.bin"
    private nonisolated static let embeddingDim = 512
    private nonisolated static let bytesPerEmbedding = embeddingDim * MemoryLayout<Float>.size // 2048

    // MARK: - SceneIndexRepository

    nonisolated func loadRecords() async throws -> [IndexedSceneRecord] {
        let (jsonURL, _) = try storageURLs()
        let fm = FileManager.default
        guard fm.fileExists(atPath: jsonURL.path) else { return [] }

        do {
            let jsonData = try Data(contentsOf: jsonURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([IndexedSceneRecord].self, from: jsonData)
        } catch {
            // Corrupted manifest — fall back to empty index.
            return []
        }
    }

    nonisolated func load() async throws -> [IndexedScene] {
        let (jsonURL, binURL) = try storageURLs()
        let fm = FileManager.default
        guard fm.fileExists(atPath: jsonURL.path),
              fm.fileExists(atPath: binURL.path) else {
            return []
        }

        let records: [IndexedSceneRecord]
        do {
            let jsonData = try Data(contentsOf: jsonURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            records = try decoder.decode([IndexedSceneRecord].self, from: jsonData)
        } catch {
            return []
        }

        let binData = try Data(contentsOf: binURL)

        return records.compactMap { record in
            let offset = record.embeddingOffset
            let end = offset + Self.bytesPerEmbedding
            guard end <= binData.count else { return nil }

            let slice = binData[offset..<end]
            let floats: [Float] = slice.withUnsafeBytes { raw in
                let bound = raw.bindMemory(to: Float.self)
                return Array(bound)
            }
            return IndexedScene(
                assetIdentifier: record.assetIdentifier,
                embedding: floats,
                dateIndexed: record.dateIndexed
            )
        }
    }

    nonisolated func append(newScenes: [IndexedScene]) async throws {
        guard !newScenes.isEmpty else { return }
        let (jsonURL, binURL) = try storageURLs(createDir: true)
        let fm = FileManager.default

        // Load existing records for asset-level dedup + current binary size.
        var existingRecords: [IndexedSceneRecord] = []
        if fm.fileExists(atPath: jsonURL.path) {
            do {
                let jsonData = try Data(contentsOf: jsonURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                existingRecords = try decoder.decode([IndexedSceneRecord].self, from: jsonData)
            } catch {
                existingRecords = []
            }
        }
        let existingIds = Set(existingRecords.map(\.assetIdentifier))

        // Only append scenes for assets not already indexed.
        let toAdd = newScenes.filter { !existingIds.contains($0.assetIdentifier) }
        guard !toAdd.isEmpty else { return }

        var currentBinSize = 0
        if fm.fileExists(atPath: binURL.path) {
            let attrs = try fm.attributesOfItem(atPath: binURL.path)
            currentBinSize = (attrs[.size] as? Int) ?? 0
        }

        // Build new embedding bytes.
        var newFloats = [Float]()
        newFloats.reserveCapacity(toAdd.count * Self.embeddingDim)
        for scene in toAdd {
            newFloats.append(contentsOf: scene.embedding)
        }
        let newBinData = newFloats.withUnsafeBytes { Data($0) }

        // Build new records with correct offsets.
        var offset = currentBinSize
        var newRecords = [IndexedSceneRecord]()
        for scene in toAdd {
            newRecords.append(IndexedSceneRecord(
                assetIdentifier: scene.assetIdentifier,
                dateIndexed: scene.dateIndexed,
                embeddingOffset: offset
            ))
            offset += Self.bytesPerEmbedding
        }

        // Append binary data.
        if fm.fileExists(atPath: binURL.path) {
            let handle = try FileHandle(forWritingTo: binURL)
            handle.seekToEndOfFile()
            handle.write(newBinData)
            handle.closeFile()
        } else {
            try newBinData.write(to: binURL, options: .atomic)
        }

        // Write combined JSON manifest atomically.
        let allRecords = existingRecords + newRecords
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(allRecords)
        try jsonData.write(to: jsonURL, options: .atomic)
    }

    nonisolated func clear() async throws {
        let (jsonURL, binURL) = try storageURLs()
        let fm = FileManager.default
        for url in [jsonURL, binURL] where fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
    }

    // MARK: - Private

    private nonisolated func storageURLs(createDir: Bool = false) throws -> (json: URL, bin: URL) {
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
        return (
            json: dir.appendingPathComponent(Self.jsonFile),
            bin:  dir.appendingPathComponent(Self.binFile)
        )
    }
}
