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

    func makeUIView(context: Context) -> NativeAdView {
        let adView = NativeAdView()
        adView.backgroundColor = UIColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1)
        adView.layer.cornerRadius = 12
        adView.clipsToBounds = true

        // Icon
        let iconView = UIImageView()
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(iconView)
        adView.iconView = iconView

        // Headline
        let headlineLabel = UILabel()
        headlineLabel.font = .systemFont(ofSize: 13, weight: .bold)
        headlineLabel.textColor = .white
        headlineLabel.numberOfLines = 2
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(headlineLabel)
        adView.headlineView = headlineLabel

        // Body
        let bodyLabel = UILabel()
        bodyLabel.font = .systemFont(ofSize: 11)
        bodyLabel.textColor = UIColor(white: 0.65, alpha: 1)
        bodyLabel.numberOfLines = 2
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        adView.addSubview(bodyLabel)
        adView.bodyView = bodyLabel

        // Call to action
        let ctaButton = UIButton(type: .system)
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

        NSLayoutConstraint.activate([
            // Icon: top-left
            iconView.topAnchor.constraint(equalTo: adView.topAnchor, constant: 10),
            iconView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 10),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            // Ad badge: next to icon
            adBadge.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            adBadge.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            adBadge.widthAnchor.constraint(equalToConstant: 22),
            adBadge.heightAnchor.constraint(equalToConstant: 14),

            // Headline: below icon
            headlineLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            headlineLabel.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 10),
            headlineLabel.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -10),

            // Body: below headline
            bodyLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 4),
            bodyLabel.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 10),
            bodyLabel.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -10),

            // CTA: bottom
            ctaButton.topAnchor.constraint(greaterThanOrEqualTo: bodyLabel.bottomAnchor, constant: 6),
            ctaButton.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 10),
            ctaButton.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -10),
            ctaButton.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -10),
            ctaButton.heightAnchor.constraint(equalToConstant: 28),
        ])

        return adView
    }

    func updateUIView(_ adView: NativeAdView, context: Context) {
        adView.nativeAd = nativeAd
        (adView.headlineView as? UILabel)?.text = nativeAd.headline
        (adView.bodyView as? UILabel)?.text = nativeAd.body
        (adView.iconView as? UIImageView)?.image = nativeAd.icon?.image
        (adView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
    }
}
