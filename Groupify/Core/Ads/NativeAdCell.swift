import Combine
import GoogleMobileAds
import SwiftUI

/// Loads and displays a single native ad that fits inside a grid cell.
/// Uses UIViewRepresentable to wrap GADNativeAdView.
struct NativeAdCell: View {
    let adUnitID: String

    @StateObject private var loader = NativeAdLoader()

    var body: some View {
        Group {
            if let nativeAd = loader.nativeAd {
                NativeAdRepresentable(nativeAd: nativeAd)
            } else {
                // Placeholder while loading
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 28/255, green: 28/255, blue: 30/255))
                    .overlay(
                        ProgressView()
                            .tint(.gray)
                    )
            }
        }
        .onAppear {
            if loader.nativeAd == nil {
                loader.load(adUnitID: adUnitID)
            }
        }
    }
}

// MARK: - Ad Loader (ObservableObject)

final class NativeAdLoader: NSObject, ObservableObject {
    @Published var nativeAd: NativeAd?
    private var adLoader: AdLoader?

    func load(adUnitID: String) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }

        let loader = AdLoader(
            adUnitID: adUnitID,
            rootViewController: rootVC,
            adTypes: [.native],
            options: nil
        )
        loader.delegate = self
        self.adLoader = loader
        loader.load(Request())
    }
}

extension NativeAdLoader: NativeAdLoaderDelegate {
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        self.nativeAd = nativeAd
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) {
        #if DEBUG
        print("[NativeAdCell] Failed to load: \(error.localizedDescription)")
        #endif
    }
}

// MARK: - UIViewRepresentable for GADNativeAdView

private struct NativeAdRepresentable: UIViewRepresentable {
    let nativeAd: NativeAd

    func makeUIView(context: Context) -> NativeAdContainerView {
        let adView = NativeAdContainerView()
        adView.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1)
        adView.layer.cornerRadius = 12
        adView.clipsToBounds = true

        // Media view for image/video assets. Registering this is required for video-enabled native ads.
        let mediaView = MediaView()
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(mediaView)
        adView.mediaView = mediaView

        // Icon
        adView.iconImageView.contentMode = .scaleAspectFit
        adView.iconImageView.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(adView.iconImageView)
        adView.iconView = adView.iconImageView

        // Headline
        adView.headlineLabel.font = .systemFont(ofSize: 13, weight: .bold)
        adView.headlineLabel.textColor = .white
        adView.headlineLabel.numberOfLines = 2
        adView.headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(adView.headlineLabel)
        adView.headlineView = adView.headlineLabel

        // Body
        adView.bodyLabel.font = .systemFont(ofSize: 11)
        adView.bodyLabel.textColor = UIColor(white: 0.65, alpha: 1)
        adView.bodyLabel.numberOfLines = 2
        adView.bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(adView.bodyLabel)
        adView.bodyView = adView.bodyLabel

        // Call to action
        let ctaButton = adView.callToActionButton
        ctaButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        ctaButton.setTitleColor(.white, for: .normal)
        ctaButton.backgroundColor = UIColor(red: 123/255, green: 97/255, blue: 255/255, alpha: 1)
        ctaButton.layer.cornerRadius = 6
        ctaButton.isUserInteractionEnabled = false
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        var ctaConfig = UIButton.Configuration.plain()
        ctaConfig.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        ctaButton.configuration = ctaConfig
        adView.addSubview(ctaButton)
        adView.callToActionView = ctaButton

        // "Ad" badge
        let adBadge = UILabel()
        adBadge.text = "Ad"
        adBadge.font = .systemFont(ofSize: 9, weight: .bold)
        adBadge.textColor = .white
        adBadge.backgroundColor = UIColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 1)
        adBadge.textAlignment = .center
        adBadge.layer.cornerRadius = 3
        adBadge.clipsToBounds = true
        adBadge.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(adBadge)

        let mediaHeightConstraint = mediaView.heightAnchor.constraint(equalToConstant: 150)
        adView.mediaHeightConstraint = mediaHeightConstraint

        NSLayoutConstraint.activate([
            mediaView.topAnchor.constraint(equalTo: adView.topAnchor),
            mediaView.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
            mediaView.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
            mediaHeightConstraint,

            // Icon: top-left
            adView.iconImageView.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 10),
            adView.iconImageView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 10),
            adView.iconImageView.widthAnchor.constraint(equalToConstant: 32),
            adView.iconImageView.heightAnchor.constraint(equalToConstant: 32),

            // Ad badge: next to icon
            adBadge.centerYAnchor.constraint(equalTo: adView.iconImageView.centerYAnchor),
            adBadge.leadingAnchor.constraint(equalTo: adView.iconImageView.trailingAnchor, constant: 6),
            adBadge.widthAnchor.constraint(equalToConstant: 22),
            adBadge.heightAnchor.constraint(equalToConstant: 14),

            // Headline: below icon
            adView.headlineLabel.topAnchor.constraint(equalTo: adView.iconImageView.bottomAnchor, constant: 8),
            adView.headlineLabel.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 10),
            adView.headlineLabel.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -10),

            // Body: below headline
            adView.bodyLabel.topAnchor.constraint(equalTo: adView.headlineLabel.bottomAnchor, constant: 4),
            adView.bodyLabel.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 10),
            adView.bodyLabel.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -10),

            // CTA: bottom
            ctaButton.topAnchor.constraint(greaterThanOrEqualTo: adView.bodyLabel.bottomAnchor, constant: 6),
            ctaButton.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 10),
            ctaButton.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -10),
            ctaButton.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -10),
            ctaButton.heightAnchor.constraint(equalToConstant: 28),
        ])

        return adView
    }

    func updateUIView(_ adView: NativeAdContainerView, context: Context) {
        let hasMedia = nativeAd.mediaContent.hasVideoContent || nativeAd.mediaContent.aspectRatio > 0
        let mediaHeight = hasMedia ? max(150, 320 / max(nativeAd.mediaContent.aspectRatio, 1.91)) : 0

        adView.mediaView?.isHidden = !hasMedia
        adView.mediaHeightConstraint?.constant = mediaHeight
        adView.mediaView?.mediaContent = nativeAd.mediaContent
        adView.nativeAd = nativeAd
        adView.headlineLabel.text = nativeAd.headline
        adView.bodyLabel.text = nativeAd.body
        adView.bodyLabel.isHidden = nativeAd.body?.isEmpty != false
        adView.iconImageView.image = nativeAd.icon?.image
        adView.iconImageView.isHidden = nativeAd.icon == nil
        adView.callToActionButton.setTitle(nativeAd.callToAction, for: .normal)
        adView.callToActionButton.isHidden = nativeAd.callToAction?.isEmpty != false
    }
}
private final class NativeAdContainerView: NativeAdView {
    let iconImageView = UIImageView()
    let headlineLabel = UILabel()
    let bodyLabel = UILabel()
    let callToActionButton = UIButton(type: .system)
    var mediaHeightConstraint: NSLayoutConstraint?
}

