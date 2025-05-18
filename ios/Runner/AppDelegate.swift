import UIKit
import Flutter
import workmanager
import BackgroundTasks

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Register for background fetch
    if #available(iOS 13.0, *) {
      BGTaskScheduler.shared.register(
        forTaskWithIdentifier: "com.wahdabank.mail.fetch",
        using: nil
      ) { task in
        // This will be called when a background fetch is triggered
        self.handleBackgroundFetch(task: task as! BGAppRefreshTask)
      }
    }

    // Register workmanager task handler
    WorkmanagerPlugin.register(with: self.registrar(forPlugin: "be.tramckrijte.workmanager.WorkmanagerPlugin")!)

    // Use setPluginRegistrantCallback for Workmanager
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
      GeneratedPluginRegistrant.register(with: registry)
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle background fetch tasks
  @available(iOS 13.0, *)
  func handleBackgroundFetch(task: BGAppRefreshTask) {
    // Schedule the next background fetch
    scheduleBackgroundFetch()

    // Create a task request to ensure we have enough time to complete the fetch
    let taskCompletionHandler = task.expirationHandler

    // Perform your email fetch operation here
    // ...

    // Mark the task as complete when done
    task.setTaskCompleted(success: true)
  }

  // Schedule the next background fetch
  @available(iOS 13.0, *)
  func scheduleBackgroundFetch() {
    let request = BGAppRefreshTaskRequest(identifier: "com.wahdabank.mail.fetch")
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes

    do {
      try BGTaskScheduler.shared.submit(request)
    } catch {
      print("Could not schedule background fetch: \(error)")
    }
  }
}
