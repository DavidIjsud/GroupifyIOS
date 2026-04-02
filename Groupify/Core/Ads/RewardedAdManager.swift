import Combine
import GoogleMobileAds
import UIKit

/// Manages loading and presenting a rewarded ad. Pre-loads the next ad
/// after each presentation so it's ready for the next trigger.
final class RewardedAdManager: NSObject, ObservableObject {
    private let adUnitID: String
    private var rewardedAd: RewardedAd?
    private var onAdDismissed: (() -> Void)?

    @Published private(set) var isAdReady: Bool = false

    init(adUnitID: String) {
        self.adUnitID = adUnitID
        super.init()
        loadAd()
    }

    /// Pre-loads a rewarded ad so it's ready to show instantly.
    func loadAd() {
        RewardedAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
            guard let self else { return }
            if let error {
                #if DEBUG
                print("[RewardedAdManager] Failed to load: \(error.localizedDescription)")
                #endif
                self.isAdReady = false
                return
            }
            self.rewardedAd = ad
            self.rewardedAd?.fullScreenContentDelegate = self
            self.isAdReady = true
            #if DEBUG
            print("[RewardedAdManager] Ad loaded and ready")
            #endif
        }
    }

    /// Shows the rewarded ad. Calls `completion` when the ad is dismissed
    /// (whether the user watched it or not), so the pipeline can proceed.
    /// If no ad is loaded, calls `completion` immediately.
    func showAd(completion: @escaping () -> Void) {
        guard let rewardedAd,
              let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
              let rootVC = windowScene.windows.first?.rootViewController else {
            // No ad available — proceed without showing.
            completion()
            return
        }

        self.onAdDismissed = completion
        rewardedAd.present(from: rootVC) {
            #if DEBUG
            print("[RewardedAdManager] User earned reward")
            #endif
        }
    }
}

// MARK: - FullScreenContentDelegate

extension RewardedAdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        // Ad was closed — run the pending callback and pre-load the next ad.
        rewardedAd = nil
        isAdReady = false
        onAdDismissed?()
        onAdDismissed = nil
        loadAd()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        #if DEBUG
        print("[RewardedAdManager] Failed to present: \(error.localizedDescription)")
        #endif
        rewardedAd = nil
        isAdReady = false
        onAdDismissed?()
        onAdDismissed = nil
        loadAd()
    }
}
