import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:workmanager/workmanager.dart';

/// Background service for email app with platform-safe implementation
///
/// This class handles background tasks for email checking and notifications
/// with proper platform detection to avoid errors on unsupported platforms.
class BackgroundService {
  // Static constants for storage keys
  static const String keyInboxLastUid = 'inbox_last_uid';
  static const String keyBackgroundEnabled = 'background_enabled';
  static const String keyLastCheckTime = 'last_check_time';

  // Task names
  static const String checkEmailTask = 'checkEmail';
  static const String syncDraftsTask = 'syncDrafts';

  // Task frequencies
  static const Duration checkEmailFrequency = Duration(minutes: 15);
  static const Duration syncDraftsFrequency = Duration(hours: 1);

  // Private singleton instance - truly private
  static final BackgroundService _instance = BackgroundService._internal();

  // Factory constructor that returns the singleton instance
  factory BackgroundService() => _instance;

  // Private constructor
  BackgroundService._internal();

  /// Check if background services are supported on this platform
  bool get isSupported {
    // Only Android supports Workmanager background tasks
    return !kIsWeb && Platform.isAndroid;
  }

  /// Initialize background services
  Future<void> initialize() async {
    if (!isSupported) {
      debugPrint('Background services not supported on this platform');
      return;
    }

    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      debugPrint('Background service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing background service: $e');
    }
  }

  /// Register periodic email checking task
  Future<void> registerEmailCheckTask() async {
    if (!isSupported) {
      debugPrint('Skipping email check task registration on unsupported platform');
      return;
    }

    try {
      await Workmanager().registerPeriodicTask(
        checkEmailTask,
        checkEmailTask,
        frequency: checkEmailFrequency,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: true,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      debugPrint('Email check task registered successfully');
    } catch (e) {
      debugPrint('Error registering email check task: $e');
    }
  }

  /// Register periodic drafts sync task
  Future<void> registerDraftsSyncTask() async {
    if (!isSupported) {
      debugPrint('Skipping drafts sync task registration on unsupported platform');
      return;
    }

    try {
      await Workmanager().registerPeriodicTask(
        syncDraftsTask,
        syncDraftsTask,
        frequency: syncDraftsFrequency,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      debugPrint('Drafts sync task registered successfully');
    } catch (e) {
      debugPrint('Error registering drafts sync task: $e');
    }
  }

  /// Cancel all background tasks
  Future<void> cancelAllTasks() async {
    if (!isSupported) {
      debugPrint('Skipping task cancellation on unsupported platform');
      return;
    }

    try {
      await Workmanager().cancelAll();
      debugPrint('All background tasks cancelled');
    } catch (e) {
      debugPrint('Error cancelling background tasks: $e');
    }
  }

  /// Cancel specific task by name
  Future<void> cancelTask(String taskName) async {
    if (!isSupported) {
      debugPrint('Skipping task cancellation on unsupported platform');
      return;
    }

    try {
      await Workmanager().cancelByUniqueName(taskName);
      debugPrint('Task $taskName cancelled');
    } catch (e) {
      debugPrint('Error cancelling task $taskName: $e');
    }
  }

  /// Static methods for backward compatibility with bg_service.dart

  /// Check for new mail in background (static version for backward compatibility)
  /// Now accepts an optional isBackground parameter to match existing code
  static Future<void> checkForNewMail([bool isBackground = false]) async {
    if (kIsWeb || !Platform.isAndroid) {
      debugPrint('Skipping checkForNewMail on unsupported platform');
      return;
    }

    try {
      // This would normally call your email checking service
      debugPrint('Checking for new emails in background (static method), isBackground: $isBackground');

      // Add your email checking logic here
      // For example:
      // final mailboxController = Get.find<MailBoxController>();
      // await mailboxController.checkForNewMail();
    } catch (e) {
      debugPrint('Error checking for new mail: $e');
    }
  }

  /// Initialize service (static version for backward compatibility)
  static Future<void> initializeService() async {
    if (kIsWeb || !Platform.isAndroid) {
      debugPrint('Skipping initializeService on unsupported platform');
      return;
    }

    try {
      // Use the singleton instance directly
      await _instance.initialize();
      debugPrint('Background service initialized (static method)');
    } catch (e) {
      debugPrint('Error initializing background service: $e');
    }
  }

  /// Check if service is enabled (static version for backward compatibility)
  static Future<bool> isServiceEnabled() async {
    if (kIsWeb || !Platform.isAndroid) {
      debugPrint('Background service not supported on this platform');
      return false;
    }

    // This would normally check if the service is enabled in settings
    return true;
  }

  /// Start service (static version for backward compatibility)
  static Future<void> startService() async {
    if (kIsWeb || !Platform.isAndroid) {
      debugPrint('Skipping startService on unsupported platform');
      return;
    }

    try {
      // Register email check task using the singleton instance
      await _instance.registerEmailCheckTask();
      debugPrint('Background service started (static method)');
    } catch (e) {
      debugPrint('Error starting background service: $e');
    }
  }

  /// Optimize battery usage (static version for backward compatibility)
  static Future<void> optimizeBatteryUsage() async {
    if (kIsWeb || !Platform.isAndroid) {
      debugPrint('Skipping battery optimization on unsupported platform');
      return;
    }

    try {
      // This would normally request battery optimization exemption
      debugPrint('Requested battery optimization exemption');
    } catch (e) {
      debugPrint('Error requesting battery optimization: $e');
    }
  }
}

/// Global callback dispatcher for background tasks
@pragma('vm:entry-point')
void callbackDispatcher() {
  // Skip on unsupported platforms
  if (kIsWeb || !(Platform.isAndroid)) {
    debugPrint('Background callback not supported on this platform');
    return;
  }

  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('Executing background task: $taskName');

    try {
      switch (taskName) {
        case BackgroundService.checkEmailTask:
        // Call the static method for backward compatibility
          await BackgroundService.checkForNewMail(true);
          break;

        case BackgroundService.syncDraftsTask:
        // This would normally sync drafts with server
          debugPrint('Syncing drafts in background');
          break;

        default:
          debugPrint('Unknown task: $taskName');
          return Future.value(false);
      }

      return Future.value(true);
    } catch (e) {
      debugPrint('Error executing background task $taskName: $e');
      return Future.value(false);
    }
  });
}
