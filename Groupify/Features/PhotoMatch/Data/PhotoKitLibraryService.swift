import Foundation
import Photos
import UIKit

struct PhotoKitLibraryService: PhotoLibraryService, Sendable {

    nonisolated func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    nonisolated func fetchAllAssets() -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets = [PHAsset]()
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    nonisolated func loadThumbnail(
        for asset: PHAsset,
        targetSize: CGSize
    ) async throws -> UIImage {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                guard !resumed else { return }
                resumed = true
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: PhotoKitError.thumbnailFailed)
                }
            }
        }
    }

    nonisolated func loadFullImage(for asset: PHAsset) async throws -> UIImage {
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none
        options.isNetworkAccessAllowed = true

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                guard !resumed else { return }
                resumed = true
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: PhotoKitError.fullImageFailed)
                }
            }
        }
    }

    nonisolated func exportForSharing(assetIdentifiers: [String]) async throws -> [URL] {
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: assetIdentifiers, options: nil
        )
        var assets = [PHAsset]()
        fetchResult.enumerateObjects { a, _, _ in assets.append(a) }

        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GroupifyShare", isDirectory: true)
        try? FileManager.default.removeItem(at: tmp) // clean previous
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        var urls = [URL]()
        for (i, asset) in assets.enumerated() {
            let image = try await loadFullImage(for: asset)
            if let data = image.jpegData(compressionQuality: 0.85) {
                let url = tmp.appendingPathComponent("match_\(i).jpg")
                try data.write(to: url)
                urls.append(url)
            }
        }
        return urls
    }

    enum PhotoKitError: Error, LocalizedError {
        case thumbnailFailed
        case fullImageFailed

        var errorDescription: String? {
            switch self {
            case .thumbnailFailed: return "Failed to load photo thumbnail"
            case .fullImageFailed: return "Failed to load full photo"
            }
        }
    }
}
