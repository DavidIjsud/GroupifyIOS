//
//  GroupifyApp.swift
//  Groupify
//
//  Created by David Garcia on 3/3/26.
//

import AdSupport
import AppTrackingTransparency
import SwiftUI
import FirebaseCore
import GoogleMobileAds

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        MobileAds.shared.start(completionHandler: nil)
        RemoteConfigManager.shared.fetchAndActivate()

        // Request App Tracking Transparency permission, then log the IDFA.
        // Delayed so the app's UI is presented first (ATT requires a visible window).
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { status in
                let idfa = ASIdentifierManager.shared().advertisingIdentifier
                let statusName: String
                switch status {
                case .authorized:     statusName = "authorized"
                case .denied:         statusName = "denied"
                case .restricted:     statusName = "restricted"
                case .notDetermined:  statusName = "notDetermined"
                @unknown default:     statusName = "unknown"
                }
                print("[IDFA] Tracking status: \(statusName)")
                print("[IDFA] Advertising Identifier: \(idfa.uuidString)")
            }
        }

        return true
    }
}

@main
struct GroupifyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
