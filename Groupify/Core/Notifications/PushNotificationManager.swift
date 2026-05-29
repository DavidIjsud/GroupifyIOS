import FirebaseMessaging
import UIKit
import UserNotifications

/// Firebase Cloud Messaging + system notification wiring, kept as an `AppDelegate`
/// extension so the UIKit/Messaging delegate callbacks live in one place.
///
/// Flow: `configurePushNotifications` sets the delegates and asks for permission;
/// on grant we register with APNs; the APNs token is handed to Firebase, which
/// returns an FCM token used to target this install.
extension AppDelegate: MessagingDelegate, UNUserNotificationCenterDelegate {

    /// Call once from `didFinishLaunchingWithOptions`, after `FirebaseApp.configure()`.
    func configurePushNotifications(_ application: UIApplication) {
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, error in
            #if DEBUG
            if let error {
                print("[Push] Authorization error: \(error.localizedDescription)")
            } else {
                print("[Push] Notification permission granted: \(granted)")
            }
            #endif
            guard granted else { return }
            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }

    // MARK: - APNs registration

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Hand the APNs token to Firebase so it can issue/refresh the FCM token.
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("[Push] Failed to register with APNs: \(error.localizedDescription)")
        #endif
    }

    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        #if DEBUG
        print("[Push] FCM registration token: \(fcmToken ?? "nil")")
        #endif
        // Subscribe every install to a broadcast topic so notifications can be
        // sent to all users from the Firebase console without managing tokens.
        messaging.subscribe(toTopic: "all")
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Present banners/sound while the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .badge, .sound])
    }

    /// Handle the user tapping a delivered notification.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        #if DEBUG
        print("[Push] Tapped notification: \(response.notification.request.content.userInfo)")
        #endif
        completionHandler()
    }
}
