import GoogleMobileAds
import SwiftUI

/// A reusable SwiftUI wrapper around BannerView that displays a
/// standard-sized banner ad. Uses a fixed intrinsic content size
/// so it doesn't stretch the surrounding SwiftUI layout.
struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        if banner.rootViewController == nil,
           let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
           let rootVC = windowScene.windows.first?.rootViewController {
            banner.rootViewController = rootVC
            banner.load(Request())
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            #if DEBUG
            print("[BannerAdView] Ad loaded successfully")
            #endif
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            #if DEBUG
            print("[BannerAdView] Failed to load ad: \(error.localizedDescription)")
            #endif
        }
    }
}
