import Foundation

struct FileFaceIndexRepository: FaceIndexRepository, Sendable {
    private nonisolated static let dirName = "GroupifyIndex"
    private nonisolated static let jsonFile = "face_index.json"
    private nonisolated static let binFile  = "embeddings.bin"
    private nonisolated static let embeddingDim = 128

    // MARK: - FaceIndexRepository

    nonisolated func load() async throws -> [IndexedFace] {
        let (jsonURL, binURL) = try storageURLs()
        let fm = FileManager.default
        guard fm.fileExists(atPath: jsonURL.path),
              fm.fileExists(atPath: binURL.path) else {
            return []
        }

        let jsonData = try Data(contentsOf: jsonURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let records = try decoder.decode([IndexedFaceRecord].self, from: jsonData)

        let binData = try Data(contentsOf: binURL)
        let expectedSize = records.count * Self.embeddingDim * MemoryLayout<Float>.size
        guard binData.count == expectedSize else { return [] }

        return binData.withUnsafeBytes { raw -> [IndexedFace] in
            let floats = raw.bindMemory(to: Float.self)
            return records.enumerated().map { idx, record in
                let start = idx * Self.embeddingDim
                let slice = Array(floats[start..<start + Self.embeddingDim])
                return IndexedFace(
                    assetIdentifier: record.assetIdentifier,
                    embedding: FaceEmbedding(values: slice, isL2Normalized: true),
                    dateIndexed: record.dateIndexed
                )
            }
        }
    }

    nonisolated func save(_ faces: [IndexedFace]) async throws {
        let (jsonURL, binURL) = try storageURLs(createDir: true)

        // Binary: contiguous Float32 values.
        var floats = [Float]()
        floats.reserveCapacity(faces.count * Self.embeddingDim)
        for face in faces {
            floats.append(contentsOf: face.embedding.values)
        }
        let binData = floats.withUnsafeBytes { Data($0) }

        // JSON manifest.
        let records = faces.map {
            IndexedFaceRecord(assetIdentifier: $0.assetIdentifier, dateIndexed: $0.dateIndexed)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(records)

        try binData.write(to: binURL, options: .atomic)
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
