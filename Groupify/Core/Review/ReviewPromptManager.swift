import StoreKit
import UIKit

/// Gates and presents the App Store in-app review prompt at a genuine moment of
/// delight (a successful group save).
///
/// iOS independently caps the prompt at 3 per 365 days and may silently swallow
/// any request, so this manager adds an app-level gate: stay quiet until the
/// user has clearly adopted the feature, then ask at most once per app version.
enum ReviewPromptManager {
    private static let saveCountKey = "review.successfulSaveCount"
    private static let lastVersionKey = "review.lastVersionPromptedForReview"

    /// Successful group saves required before the prompt becomes eligible. The
    /// first two saves stay silent so we don't ask before the user has felt the
    /// value of the feature.
    private static let saveThreshold = 3

    /// Records a successful group save and, when the gate allows, asks iOS to
    /// show the review prompt. Safe to call on every save — the gate throttles.
    static func registerSuccessfulSaveAndRequestReview() {
        let defaults = UserDefaults.standard

        let saveCount = defaults.integer(forKey: saveCountKey) + 1
        defaults.set(saveCount, forKey: saveCountKey)
        guard saveCount >= saveThreshold else { return }

        // Ask at most once per app version (Apple's recommended pattern).
        let currentVersion = Bundle.main
            .infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        guard defaults.string(forKey: lastVersionKey) != currentVersion else { return }
        defaults.set(currentVersion, forKey: lastVersionKey)

        // Let the Save sheet finish dismissing before presenting the prompt.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard let scene = activeWindowScene else { return }
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    private static var activeWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }
}
