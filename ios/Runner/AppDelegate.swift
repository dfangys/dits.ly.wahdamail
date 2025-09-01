import UIKit
import Flutter
#if canImport(workmanager_apple)
import workmanager_apple
#endif
#if canImport(workmanager)
import workmanager
#endif
import UserNotifications   // ⚠︎ keep the import

@main
@objc class AppDelegate: FlutterAppDelegate {   // ← remove extra protocol

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    // iOS notifications permission ➜ APNs registration
    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { granted, error in
        if let error = error {
          print("❌ Notification permission error:", error)
        }
        DispatchQueue.main.async {
          application.registerForRemoteNotifications()
        }
    }

    // 3. Normal Flutter bootstrap
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // APNs token ⇒ send to your server
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    super.application(application,
                      didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    let tokenHex = deviceToken.map { String(format: "%02hhx", $0) }.joined()
    print("📮 APNs token:", tokenHex)
    // TODO: POST tokenHex to backend
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ Failed to register with APNs:", error)
  }

  // ✅ add `override` because FlutterAppDelegate already provides this method
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    // show alerts even when app is in foreground
    completionHandler([.alert, .badge, .sound])
  }

  // Silent-push/background-fetch handler (optional)
  override func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable : Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    super.application(
      application,
      didReceiveRemoteNotification: userInfo,
      fetchCompletionHandler: completionHandler
    )
  }
}