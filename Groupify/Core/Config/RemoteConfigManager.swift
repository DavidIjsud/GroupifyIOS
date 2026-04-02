import Combine
import FirebaseRemoteConfig
import Foundation

/// Centralized manager for Firebase Remote Config.
/// Fetches and caches remote values with sensible defaults.
/// Add new keys to `DefaultKeys` and matching properties as needed.
final class RemoteConfigManager: ObservableObject {

    // MARK: - Singleton

    static let shared = RemoteConfigManager()

    // MARK: - Default keys and values

    private enum DefaultKeys {
        static let showAds = "show_ads"
    }

    private static let defaults: [String: NSObject] = [
        DefaultKeys.showAds: false as NSObject
    ]

    // MARK: - Published values

    @Published private(set) var showAds: Bool = true

    // MARK: - Private

    private let remoteConfig: RemoteConfig

    private init() {
        remoteConfig = RemoteConfig.remoteConfig()

        let settings = RemoteConfigSettings()
        #if DEBUG
        // Fetch frequently during development (no throttle).
        settings.minimumFetchInterval = 0
        #else
        // Production: fetch at most every 60 minutes.
        settings.minimumFetchInterval = 3600
        #endif
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults(Self.defaults)
    }

    // MARK: - Fetch

    /// Fetches remote values and activates them. Safe to call multiple times.
    func fetchAndActivate() {
        remoteConfig.fetchAndActivate { [weak self] status, error in
            guard let self else { return }

            if let error {
                #if DEBUG
                print("[RemoteConfig] Fetch error: \(error.localizedDescription)")
                #endif
                return
            }

            #if DEBUG
            print("[RemoteConfig] Fetch status: \(status.rawValue)")
            #endif

            self.applyValues()
        }
    }

    // MARK: - Apply

    private func applyValues() {
        let newShowAds = remoteConfig.configValue(forKey: DefaultKeys.showAds).boolValue

        DispatchQueue.main.async { [weak self] in
            self?.showAds = newShowAds
            #if DEBUG
            print("[RemoteConfig] show_ads = \(newShowAds)")
            #endif
        }
    }
}
