import Foundation

struct FileFaceIndexRepository: FaceIndexRepository, Sendable {
    private nonisolated static let dirName = "GroupifyIndex"
    private nonisolated static let jsonFile = "face_index.json"
    private nonisolated static let binFile  = "embeddings.bin"
    private nonisolated static let embeddingDim = 128
    private nonisolated static let bytesPerEmbedding = embeddingDim * MemoryLayout<Float>.size // 512

    // MARK: - FaceIndexRepository

    nonisolated func loadRecords() async throws -> [IndexedFaceRecord] {
        let (jsonURL, _) = try storageURLs()
        let fm = FileManager.default
        guard fm.fileExists(atPath: jsonURL.path) else { return [] }

        do {
            let jsonData = try Data(contentsOf: jsonURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([IndexedFaceRecord].self, from: jsonData)
        } catch {
            // Corrupted manifest — fall back to empty index.
            return []
        }
    }

    nonisolated func load() async throws -> [IndexedFace] {
        let (jsonURL, binURL) = try storageURLs()
        let fm = FileManager.default
        guard fm.fileExists(atPath: jsonURL.path),
              fm.fileExists(atPath: binURL.path) else {
            return []
        }

        let records: [IndexedFaceRecord]
        do {
            let jsonData = try Data(contentsOf: jsonURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            records = try decoder.decode([IndexedFaceRecord].self, from: jsonData)
        } catch {
            // Corrupted manifest — fall back to empty.
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
            return IndexedFace(
                assetIdentifier: record.assetIdentifier,
                faceIndexInAsset: record.faceIndexInAsset,
                boundingBox: record.boundingBox,
                embedding: FaceEmbedding(values: floats, isL2Normalized: true),
                dateIndexed: record.dateIndexed
            )
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

        // JSON manifest with offsets.
        let records = faces.enumerated().map { idx, face in
            IndexedFaceRecord(
                assetIdentifier: face.assetIdentifier,
                faceIndexInAsset: face.faceIndexInAsset,
                boundingBox: face.boundingBox,
                dateIndexed: face.dateIndexed,
                embeddingOffset: idx * Self.bytesPerEmbedding
            )
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(records)

        try binData.write(to: binURL, options: .atomic)
        try jsonData.write(to: jsonURL, options: .atomic)
    }

    nonisolated func append(newFaces: [IndexedFace]) async throws {
        guard !newFaces.isEmpty else { return }
        let (jsonURL, binURL) = try storageURLs(createDir: true)
        let fm = FileManager.default

        // Load existing records and compute current binary size.
        var existingRecords: [IndexedFaceRecord] = []
        var currentBinSize = 0

        if fm.fileExists(atPath: jsonURL.path) {
            do {
                let jsonData = try Data(contentsOf: jsonURL)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                existingRecords = try decoder.decode([IndexedFaceRecord].self, from: jsonData)
            } catch {
                // Corrupted — start fresh.
                existingRecords = []
            }
        }

        if fm.fileExists(atPath: binURL.path) {
            let attrs = try fm.attributesOfItem(atPath: binURL.path)
            currentBinSize = (attrs[.size] as? Int) ?? 0
        }

        // Build new embedding bytes.
        var newFloats = [Float]()
        newFloats.reserveCapacity(newFaces.count * Self.embeddingDim)
        for face in newFaces {
            newFloats.append(contentsOf: face.embedding.values)
        }
        let newBinData = newFloats.withUnsafeBytes { Data($0) }

        // Build new records with correct offsets.
        var offset = currentBinSize
        var newRecords = [IndexedFaceRecord]()
        for face in newFaces {
            newRecords.append(IndexedFaceRecord(
                assetIdentifier: face.assetIdentifier,
                faceIndexInAsset: face.faceIndexInAsset,
                boundingBox: face.boundingBox,
                dateIndexed: face.dateIndexed,
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
