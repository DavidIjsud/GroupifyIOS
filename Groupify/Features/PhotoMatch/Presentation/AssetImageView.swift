import Photos
import SwiftUI

/// Plain square thumbnail for a photo-library asset, addressed by local identifier.
/// Used by group collages and the group-detail grid (no score/selection chrome,
/// unlike `MatchThumbnailView`).
struct AssetImageView: View {
    let assetIdentifier: String
    var cornerRadius: CGFloat = 0

    @State private var image: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    AppTheme.cardHi
                }
            }
            .task(id: assetIdentifier) {
                let scale = UIScreen.main.scale
                let px = CGSize(
                    width: max(geo.size.width, 1) * scale,
                    height: max(geo.size.height, 1) * scale
                )
                image = await AssetThumbnailLoader.shared.load(
                    assetIdentifier: assetIdentifier,
                    targetPixelSize: px
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Shared thumbnail loader (cached)

/// Loads and caches PHAsset thumbnails by identifier. Mirrors the cache used in
/// `MatchThumbnailView`, kept separate so neither view affects the other.
final class AssetThumbnailLoader: @unchecked Sendable {
    static let shared = AssetThumbnailLoader()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 300
    }

    func load(assetIdentifier: String, targetPixelSize: CGSize) async -> UIImage? {
        let key = "\(assetIdentifier)_\(Int(targetPixelSize.width))" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let result = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetIdentifier], options: nil
        )
        guard let asset = result.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        let image: UIImage? = await withCheckedContinuation { continuation in
            var resumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetPixelSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !isDegraded else { return }
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: image)
            }
        }

        if let image {
            cache.setObject(image, forKey: key)
        }
        return image
    }
}
