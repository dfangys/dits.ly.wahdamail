import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' hide Priority;
import 'package:get/get.dart';
import 'package:wahda_bank/services/background_service.dart';
import 'package:wahda_bank/app/controllers/email_fetch_controller.dart';
import 'package:wahda_bank/app/controllers/background_task_controller.dart';
/// Background service wrapper for legacy compatibility
///
/// This service provides backward compatibility with the old background
/// service implementation while delegating to the new BackgroundService class.
class BgService {
  // Notification channel details
  static const String notificationChannelId = 'com.wahda_bank.email_notifications';
  static const String notificationChannelName = 'Email Notifications';
  static const String notificationChannelDescription = 'Notifications for new emails';

  // Notification IDs
  static const int newEmailNotificationId = 1;
  static const int backgroundServiceNotificationId = 2;

  // Notification plugin
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Background service instance
  static final BackgroundService _backgroundService = BackgroundService();

  // Status tracking
  static final RxBool _isRunning = false.obs;
  static bool get isRunning => _isRunning.value;

  // Error tracking
  static String? _lastError;
  static String? get lastError => _lastError;

  // Singleton instance
  static final BgService _instance = BgService._internal();
  static BgService get instance => _instance;

  // Private constructor
  BgService._internal();

  /// Initialize notifications
  static Future<void> _initializeNotifications() async {
    if (!Platform.isAndroid) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      notificationChannelName,
      description: notificationChannelDescription,
      importance: Importance.high,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    // Navigate to inbox or specific email based on payload
    if (response.payload != null) {
      // Example: Navigate to specific email
      // Get.toNamed('/email/${response.payload}');
    } else {
      // Navigate to inbox
      // Get.toNamed('/inbox');
    }
  }

  /// Show new email notification
  static Future<void> showNewEmailNotification(String sender, String subject) async {
    if (!Platform.isAndroid) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      notificationChannelId,
      notificationChannelName,
      channelDescription: notificationChannelDescription,
      importance: Importance.high,
      // priority: Priority.high,
      ticker: 'New Email',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      newEmailNotificationId,
      'New Email from $sender',
      subject,
      notificationDetails,
    );
  }

  /// Show background service notification
  static Future<void> showBackgroundServiceNotification(String title, String body) async {
    if (!Platform.isAndroid) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      notificationChannelId,
      notificationChannelName,
      channelDescription: notificationChannelDescription,
      importance: Importance.low,
      // priority: Priority.low,
      ongoing: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _notificationsPlugin.show(
      backgroundServiceNotificationId,
      title,
      body,
      notificationDetails,
    );
  }

  /// Initialize background services and tasks
  Future<void> initialize() async {
    // Guard for unsupported platforms
    if (!Platform.isAndroid) return;

    _isRunning.value = true;

    try {
      // Initialize notifications
      await _initializeNotifications();

      // Initialize background service
      await BackgroundService.initializeService();

      // Start service immediately if user has it enabled
      if (await BackgroundService.isServiceEnabled()) {
        await BackgroundService.startService();
      }

      // Register periodic email checks
      await registerPeriodicEmailChecks();

      if (kDebugMode) {
        print('Background tasks initialized on Android');
      }

      _isRunning.value = false;
    } catch (e) {
      _lastError = e.toString();
      _isRunning.value = false;

      if (kDebugMode) {
        print('Error initializing background tasks: $e');
      }
    }
  }

  /// Register a 15-min periodic check for new mail
  Future<void> registerPeriodicEmailChecks() async {
    // Only Android supports Workmanager periodic tasks
    if (!kIsWeb && Platform.isAndroid) {
      try {
        // Cancel any existing tasks first
        await Workmanager().cancelAll();

        await Workmanager().registerPeriodicTask(
          'com.wahda_bank.emailCheck',
          'emailBackgroundCheck',
          frequency: const Duration(minutes: 15),
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
          existingWorkPolicy: ExistingWorkPolicy.replace,
          backoffPolicy: BackoffPolicy.exponential,
        );

        if (kDebugMode) print('🕒 Periodic email checks registered');
      } on PlatformException catch (err, stack) {
        // On iOS (or if native side fails), just log and move on
        if (kDebugMode) {
          print('⚠️ Workmanager.registerPeriodicTask failed: $err');
          print(stack);
        }
      } catch (any) {
        // Fallback for any other errors
        if (kDebugMode) print('⚠️ Unexpected error registering periodic task: $any');
      }
    } else {
      if (kDebugMode) print('ℹ️ Skipping periodic email checks on non-Android platform');
    }
  }
  /// Request necessary permissions for background operation
  static Future<void> requestBackgroundPermissions() async {
    // Only request on Android
    if (Platform.isAndroid) {
      await BackgroundService.optimizeBatteryUsage();
    }
  }

  /// Check for new mail
  static Future<void> checkForNewMail([bool isBackground = false]) async {
    if (!Platform.isAndroid) return;

    _isRunning.value = true;

    try {
      // Show background service notification if running in background
      if (isBackground) {
        await showBackgroundServiceNotification(
          'Checking for new emails',
          'Wahda Bank Email is checking for new messages',
        );
      }

      // Use GetX dependency injection to get controllers if available
      if (Get.isRegistered<EmailFetchController>()) {
        final fetchController = Get.find<EmailFetchController>();

        // Check if we have a background task controller
        if (Get.isRegistered<BackgroundTaskController>()) {
          final taskController = Get.find<BackgroundTaskController>();

          // Queue the operation in the background task controller
          taskController.queueOperation(() async {
            await fetchController.checkForNewEmails(isBackground: isBackground);
          }, priority: Priority.high);
        } else {
          // Fall back to direct call
          await fetchController.checkForNewEmails(isBackground: isBackground);
        }
      }

      // Cancel background service notification if running in background
      if (isBackground) {
        await _notificationsPlugin.cancel(backgroundServiceNotificationId);
      }

      _isRunning.value = false;
    } catch (e) {
      _lastError = e.toString();
      _isRunning.value = false;

      // Cancel background service notification if running in background
      if (isBackground) {
        await _notificationsPlugin.cancel(backgroundServiceNotificationId);
      }

      if (kDebugMode) {
        print('Error checking for new mail: $e');
      }
    }
  }

  /// Start background service
  static Future<void> startBackgroundService() async {
    if (!Platform.isAndroid) return;

    await BackgroundService.startService();
  }

  /// Stop background service
  static Future<void> stopBackgroundService() async {
    if (!Platform.isAndroid) return;

    await BackgroundService().cancelAllTasks();
  }

  /// Check if background service is enabled
  static Future<bool> isBackgroundServiceEnabled() async {
    if (!Platform.isAndroid) return false;

    return await BackgroundService.isServiceEnabled();
  }

  /// Enable background service
  static Future<void> enableBackgroundService() async {
    if (!Platform.isAndroid) return;

    await BackgroundService.enableService();
  }

  /// Disable background service
  static Future<void> disableBackgroundService() async {
    if (!Platform.isAndroid) return;

    await BackgroundService.disableService();
  }

  /// Get last check time
  static Future<DateTime?> getLastCheckTime() async {
    if (!Platform.isAndroid) return null;

    return await BackgroundService.getLastCheckTime();
  }
}

/// Background fetch headless task entry point
@pragma('vm:entry-point')
void backgroundFetchHeadlessTask() {
  if (!Platform.isAndroid) return;

  Workmanager().executeTask((name, data) async {
    try {
      // Delegate to BackgroundService
      await BackgroundService().checkForNewMail(true);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error in background fetch headless task: $e');
      }
      return false;
    }
  });
}

// Static methods for backward compatibility
Future<void> initializeBackgroundTasks() async {
  await BgService.instance.initialize();
}

Future<void> registerPeriodicEmailChecks() async {
  await BgService.instance.registerPeriodicEmailChecks();
}
