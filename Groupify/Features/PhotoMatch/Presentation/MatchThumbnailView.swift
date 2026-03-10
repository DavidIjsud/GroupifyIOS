import Photos
import SwiftUI

struct MatchThumbnailView: View {
    let assetIdentifier: String
    let scorePercent: Int
    var isSelected: Bool = false

    @State private var thumbnail: UIImage?

    private let accent = Color(red: 123/255, green: 97/255, blue: 255/255)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Thumbnail
                Group {
                    if let thumb = thumbnail {
                        Image(uiImage: thumb)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Rectangle()
                            .fill(Color(red: 28/255, green: 28/255, blue: 30/255))
                            .overlay(
                                ProgressView()
                                    .tint(.white)
                            )
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()

                // Dimming overlay when selected
                if isSelected {
                    Color.black.opacity(0.3)
                }

                // Score badge (bottom-trailing)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("\(scorePercent)%")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(accent.opacity(0.9))
                            .clipShape(Capsule())
                            .padding(6)
                    }
                }

                // Selection checkmark (top-trailing)
                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(accent)
                                .background(Circle().fill(Color.white).padding(2))
                                .padding(8)
                        }
                        Spacer()
                    }
                }
            }
            .task(id: assetIdentifier) {
                let scale = UIScreen.main.scale
                let pxSize = CGSize(
                    width: geo.size.width * scale,
                    height: geo.size.height * scale
                )
                thumbnail = await Self.loadThumbnail(
                    assetIdentifier: assetIdentifier,
                    targetPixelSize: pxSize
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accent, lineWidth: isSelected ? 3 : 0)
        )
    }

    // MARK: - Thumbnail Loading with Cache

    private nonisolated static let cache = ThumbnailCache()

    private static func loadThumbnail(
        assetIdentifier: String,
        targetPixelSize: CGSize
    ) async -> UIImage? {
        let cacheKey = "\(assetIdentifier)_\(Int(targetPixelSize.width))"
        if let cached = cache.get(cacheKey) {
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
                // Skip degraded intermediate results.
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard !isDegraded else { return }
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: image)
            }
        }

        if let image {
            cache.set(image, forKey: cacheKey)
        }
        return image
    }
}

// MARK: - NSCache wrapper (Sendable)

private final class ThumbnailCache: @unchecked Sendable {
    private let storage = NSCache<NSString, UIImage>()

    init() {
        storage.countLimit = 200
    }

    func get(_ key: String) -> UIImage? {
        storage.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, forKey key: String) {
        storage.setObject(image, forKey: key as NSString)
    }
}
