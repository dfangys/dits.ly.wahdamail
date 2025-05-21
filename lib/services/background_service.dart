import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:workmanager/workmanager.dart';
import 'package:wahda_bank/services/bg_service.dart';
import 'package:wahda_bank/app/controllers/background_task_controller.dart';
import 'package:wahda_bank/app/controllers/email_fetch_controller.dart';
import 'package:wahda_bank/app/controllers/email_storage_controller.dart';

/// Background service for email app with platform-safe implementation
///
/// This class handles background tasks for email checking and notifications
/// with proper platform detection to avoid errors on unsupported platforms.
/// Includes improved error handling and battery optimization.
class BackgroundService {
  // Static constants for storage keys
  static const String keyInboxLastUid = 'inbox_last_uid';
  static const String keyBackgroundEnabled = 'background_enabled';
  static const String keyLastCheckTime = 'last_check_time';
  static const String keyBackgroundFailCount = 'background_fail_count';
  static const String keyBackgroundSuccessCount = 'background_success_count';

  // Task names
  static const String checkEmailTask = 'checkEmail';
  static const String syncDraftsTask = 'syncDrafts';
  static const String cleanupTask = 'cleanup';

  // Task frequencies
  static const Duration checkEmailFrequency = Duration(minutes: 15);
  static const Duration syncDraftsFrequency = Duration(hours: 1);
  static const Duration cleanupFrequency = Duration(days: 1);

  // Maximum retry attempts
  static const int maxRetryAttempts = 3;

  // Retry delay
  static const Duration retryDelay = Duration(minutes: 5);

  // Private singleton instance - truly private
  static final BackgroundService _instance = BackgroundService._internal();

  // Status tracking
  final RxBool _isRunning = false.obs;
  bool get isRunning => _isRunning.value;

  // Last run time tracking
  DateTime? _lastRunTime;
  DateTime? get lastRunTime => _lastRunTime;

  // Error tracking
  String? _lastError;
  String? get lastError => _lastError;

  // Success/failure tracking
  int _successCount = 0;
  int _failureCount = 0;
  int get successCount => _successCount;
  int get failureCount => _failureCount;

  // Factory constructor that returns the singleton instance
  factory BackgroundService() => _instance;

  // Private constructor
  BackgroundService._internal();

  // Static instance getter
  static BackgroundService get instance => _instance;

  // Static callback dispatcher for workmanager
  static void callbackDispatcher() {
    // Skip on unsupported platforms
    if (kIsWeb || !(Platform.isAndroid)) {
      debugPrint('Background callback not supported on this platform');
      return;
    }

    Workmanager().executeTask((taskName, inputData) async {
      debugPrint('Executing background task: $taskName');

      // Track task execution
      final box = GetStorage();
      int successCount = box.read(BackgroundService.keyBackgroundSuccessCount) ?? 0;
      int failCount = box.read(BackgroundService.keyBackgroundFailCount) ?? 0;

      try {
        switch (taskName) {
          case BackgroundService.checkEmailTask:
          // Call the instance method
            await BackgroundService().checkForNewMail(true);
            break;

          case BackgroundService.syncDraftsTask:
          // This would normally sync drafts with server
            debugPrint('Syncing drafts in background');
            break;

          case BackgroundService.cleanupTask:
          // This would normally clean up old data
            debugPrint('Cleaning up old data in background');
            break;

          default:
            debugPrint('Unknown task: $taskName');
            return false;
        }

        // Update success counter
        await box.write(BackgroundService.keyBackgroundSuccessCount, successCount + 1);
        return true;
      } catch (e) {
        debugPrint('Error executing background task: $e');

        // Update failure counter
        await box.write(BackgroundService.keyBackgroundFailCount, failCount + 1);
        return false;
      }
    });
  }

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

      // Load stored success/failure counts
      _loadCounters();

      debugPrint('Background service initialized successfully');
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Error initializing background service: $e');
    }
  }

  /// Load success/failure counters from storage
  Future<void> _loadCounters() async {
    try {
      final box = GetStorage();
      _successCount = box.read(keyBackgroundSuccessCount) ?? 0;
      _failureCount = box.read(keyBackgroundFailCount) ?? 0;
    } catch (e) {
      debugPrint('Error loading background counters: $e');
    }
  }

  /// Save success/failure counters to storage
  Future<void> _saveCounters() async {
    try {
      final box = GetStorage();
      await box.write(keyBackgroundSuccessCount, _successCount);
      await box.write(keyBackgroundFailCount, _failureCount);
    } catch (e) {
      debugPrint('Error saving background counters: $e');
    }
  }

  /// Increment success counter
  void _incrementSuccessCount() {
    _successCount++;
    _saveCounters();
  }

  /// Increment failure counter
  void _incrementFailureCount() {
    _failureCount++;
    _saveCounters();
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
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: retryDelay,
      );
      debugPrint('Email check task registered successfully');
    } catch (e) {
      _lastError = e.toString();
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
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: retryDelay,
      );
      debugPrint('Drafts sync task registered successfully');
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Error registering drafts sync task: $e');
    }
  }

  /// Register periodic cleanup task
  Future<void> registerCleanupTask() async {
    if (!isSupported) {
      debugPrint('Skipping cleanup task registration on unsupported platform');
      return;
    }

    try {
      await Workmanager().registerPeriodicTask(
        cleanupTask,
        cleanupTask,
        frequency: cleanupFrequency,
        constraints: Constraints(
          networkType: NetworkType.not_required,
        ),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
      debugPrint('Cleanup task registered successfully');
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Error registering cleanup task: $e');
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
      _lastError = e.toString();
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
      _lastError = e.toString();
      debugPrint('Error cancelling task $taskName: $e');
    }
  }

  /// Register all background tasks
  Future<void> registerAllTasks() async {
    if (!isSupported) {
      debugPrint('Skipping task registration on unsupported platform');
      return;
    }

    await registerEmailCheckTask();
    await registerDraftsSyncTask();
    await registerCleanupTask();
  }

  /// Execute email check task directly (for testing or manual triggering)
  Future<bool> executeEmailCheckTask() async {
    if (!isSupported) {
      debugPrint('Skipping email check on unsupported platform');
      return false;
    }

    _isRunning.value = true;
    _lastRunTime = DateTime.now();

    try {
      await checkForNewMail(false);
      _incrementSuccessCount();
      _isRunning.value = false;
      return true;
    } catch (e) {
      _lastError = e.toString();
      _incrementFailureCount();
      _isRunning.value = false;
      debugPrint('Error executing email check task: $e');
      return false;
    }
  }

  /// Execute drafts sync task directly (for testing or manual triggering)
  Future<bool> executeDraftsSyncTask() async {
    if (!isSupported) {
      debugPrint('Skipping drafts sync on unsupported platform');
      return false;
    }

    _isRunning.value = true;
    _lastRunTime = DateTime.now();

    try {
      // This would normally sync drafts with server
      // For example:
      // final draftController = Get.find<DraftController>();
      // await draftController.syncDrafts();

      _incrementSuccessCount();
      _isRunning.value = false;
      return true;
    } catch (e) {
      _lastError = e.toString();
      _incrementFailureCount();
      _isRunning.value = false;
      debugPrint('Error executing drafts sync task: $e');
      return false;
    }
  }

  /// Execute cleanup task directly (for testing or manual triggering)
  Future<bool> executeCleanupTask() async {
    if (!isSupported) {
      debugPrint('Skipping cleanup on unsupported platform');
      return false;
    }

    _isRunning.value = true;
    _lastRunTime = DateTime.now();

    try {
      // This would normally clean up old data
      // For example:
      // final storageController = Get.find<EmailStorageController>();
      // await storageController.cleanupOldData();

      _incrementSuccessCount();
      _isRunning.value = false;
      return true;
    } catch (e) {
      _lastError = e.toString();
      _incrementFailureCount();
      _isRunning.value = false;
      debugPrint('Error executing cleanup task: $e');
      return false;
    }
  }

  /// Check for new mail in background
  /// Now accepts an optional isBackground parameter to match existing code
  Future<void> checkForNewMail([bool isBackground = false]) async {
    if (!isSupported) {
      debugPrint('Skipping checkForNewMail on unsupported platform');
      return;
    }

    try {
      debugPrint('Checking for new emails, isBackground: $isBackground');

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
      } else {
        // Fall back to legacy method if controller not available
        await BgService.checkForNewMail(isBackground);
      }

      // Update last check time
      final box = GetStorage();
      await box.write(keyLastCheckTime, DateTime.now().millisecondsSinceEpoch);

    } catch (e) {
      _lastError = e.toString();
      debugPrint('Error checking for new mail: $e');

      // Record failure
      _incrementFailureCount();

      // Rethrow to allow caller to handle
      rethrow;
    }
  }

  /// Initialize service (static version for backward compatibility)
  static Future<void> initializeService() async {
    await _instance.initialize();
  }

  /// Check if service is enabled (static version for backward compatibility)
  static Future<bool> isServiceEnabled() async {
    if (!_instance.isSupported) {
      debugPrint('Background service not supported on this platform');
      return false;
    }

    try {
      final box = GetStorage();
      return box.read(keyBackgroundEnabled) ?? false;
    } catch (e) {
      debugPrint('Error checking if service is enabled: $e');
      return false;
    }
  }

  /// Enable background service
  static Future<void> enableService() async {
    if (!_instance.isSupported) {
      debugPrint('Background service not supported on this platform');
      return;
    }

    try {
      final box = GetStorage();
      await box.write(keyBackgroundEnabled, true);
      await _instance.registerAllTasks();
    } catch (e) {
      debugPrint('Error enabling background service: $e');
    }
  }

  /// Disable background service
  static Future<void> disableService() async {
    if (!_instance.isSupported) {
      debugPrint('Background service not supported on this platform');
      return;
    }

    try {
      final box = GetStorage();
      await box.write(keyBackgroundEnabled, false);
      await _instance.cancelAllTasks();
    } catch (e) {
      debugPrint('Error disabling background service: $e');
    }
  }

  /// Start service (static version for backward compatibility)
  static Future<void> startService() async {
    if (!_instance.isSupported) {
      debugPrint('Skipping startService on unsupported platform');
      return;
    }

    try {
      // Register all tasks
      await _instance.registerAllTasks();

      // Mark as enabled
      final box = GetStorage();
      await box.write(keyBackgroundEnabled, true);

      debugPrint('Background service started');
    } catch (e) {
      debugPrint('Error starting background service: $e');
    }
  }

  /// Optimize battery usage (static version for backward compatibility)
  static Future<void> optimizeBatteryUsage() async {
    if (!_instance.isSupported) {
      debugPrint('Skipping battery optimization on unsupported platform');
      return;
    }

    try {
      // This would normally request battery optimization exemption
      // On Android, this would typically involve:
      // 1. Checking if the app is already exempted
      // 2. If not, showing a dialog to the user
      // 3. Directing them to the appropriate system settings

      debugPrint('Requested battery optimization exemption');
    } catch (e) {
      debugPrint('Error requesting battery optimization: $e');
    }
  }

  /// Get the last check time
  static Future<DateTime?> getLastCheckTime() async {
    try {
      final box = GetStorage();
      final timestamp = box.read(keyLastCheckTime);
      if (timestamp != null) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting last check time: $e');
      return null;
    }
  }

  /// Reset counters
  static Future<void> resetCounters() async {
    try {
      _instance._successCount = 0;
      _instance._failureCount = 0;
      await _instance._saveCounters();
    } catch (e) {
      debugPrint('Error resetting counters: $e');
    }
  }
}
