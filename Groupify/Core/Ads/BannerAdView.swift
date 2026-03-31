import GoogleMobileAds
import SwiftUI

/// A reusable SwiftUI wrapper around GADBannerView that displays an
/// adaptive banner ad. The banner auto-sizes to the available width.
struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView()
        banner.adUnitID = adUnitID
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.delegate = context.coordinator
        return banner
    }

    func updateUIView(_ banner: GADBannerView, context: Context) {
        // Load the ad once we have a window (needed for adaptive sizing).
        if banner.rootViewController == nil,
           let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
           let rootVC = windowScene.windows.first?.rootViewController {
            banner.rootViewController = rootVC

            let width = rootVC.view.frame.inset(by: rootVC.view.safeAreaInsets).width
            banner.adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)
            banner.load(GADRequest())
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, GADBannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            #if DEBUG
            print("[BannerAdView] Ad loaded successfully")
            #endif
        }

        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            #if DEBUG
            print("[BannerAdView] Failed to load ad: \(error.localizedDescription)")
            #endif
        }
    }
}
