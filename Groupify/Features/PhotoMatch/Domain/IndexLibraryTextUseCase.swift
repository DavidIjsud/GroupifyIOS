import Foundation
import Photos
import UIKit

/// Incrementally OCR-indexes library photos added since `since`, storing the
/// recognized text per asset. Mirrors `IndexLibraryUseCase` but for text:
/// uses a larger thumbnail so small text stays legible, and only keeps assets
/// that actually contained text. Deduped by `assetIdentifier`.
struct IndexLibraryTextUseCase: Sendable {
    let photoService: any PhotoLibraryService
    let recognizer: any TextRecognizer
    let repository: any TextIndexRepository

    /// OCR needs more pixels than face detection (300×300) to read small text.
    private nonisolated static let thumbSize = CGSize(width: 1024, height: 1024)

    struct Progress: Sendable {
        let current: Int
        let total: Int
        let status: String
        var fraction: Float { total > 0 ? Float(current) / Float(total) : 0 }
    }

    struct Result: Sendable {
        let indexedNewTexts: Int
        let scannedNewAssets: Int
        let totalInIndex: Int
    }

    /// Calls `onProgress` from a background context — callers must dispatch to MainActor.
    nonisolated func execute(
        since: Date?,
        onProgress: @escaping @Sendable (Progress) -> Void
    ) async throws -> Result {
        let existingRecords = (try? await repository.loadRecords()) ?? []
        let existingIds = Set(existingRecords.map(\.assetIdentifier))

        let assets = photoService.fetchAssets(newerThan: since)
        let total = assets.count

        if total == 0 {
            onProgress(Progress(current: 0, total: 0, status: L10n.indexUpToDate))
            return Result(
                indexedNewTexts: 0,
                scannedNewAssets: 0,
                totalInIndex: existingRecords.count
            )
        }

        var newRecords = [IndexedTextRecord]()

        for (i, asset) in assets.enumerated() {
            onProgress(Progress(
                current: i + 1, total: total,
                status: L10n.readingTextProgress(current: i + 1, total: total)
            ))

            if existingIds.contains(asset.localIdentifier) { continue }

            do {
                let thumb = try await photoService.loadHighQualityThumbnail(
                    for: asset, targetSize: Self.thumbSize
                )
                let text = try await recognizer.recognizeText(in: thumb)
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }

                newRecords.append(IndexedTextRecord(
                    assetIdentifier: asset.localIdentifier,
                    text: trimmed,
                    dateIndexed: Date()
                ))
            } catch {
                // Skip individual failures — continue indexing.
                continue
            }
        }

        if !newRecords.isEmpty {
            try await repository.append(newRecords: newRecords)
        }

        return Result(
            indexedNewTexts: newRecords.count,
            scannedNewAssets: total,
            totalInIndex: existingRecords.count + newRecords.count
        )
    }
}
