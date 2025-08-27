import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/models/sqlite_database_helper.dart';
import 'package:wahda_bank/models/sqlite_mime_storage.dart';
import 'package:wahda_bank/services/email_notification_service.dart';
import 'package:wahda_bank/services/notifications_service.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/utils/perf/perf_tracer.dart';
import 'package:workmanager/workmanager.dart';

/// Enhanced background service for email notifications with SQLite support
///
/// This service optimizes battery usage and resource consumption
/// while ensuring reliable email notifications in background.
class BackgroundService {
  static const String keyInboxLastUid = 'inboxLastUid';
  static const String keyBackgroundServiceEnabled = 'backgroundServiceEnabled';
  static const String keyBackgroundServiceLastRun = 'backgroundServiceLastRun';
  static const int notificationId = 888;

  static bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS;

  /// Initialize the background service
  static Future<void> initializeService() async {
    try {
      await GetStorage.init();

      // Initialize SQLite database
      await SQLiteDatabaseHelper.instance.database;

      // Initialize Workmanager for background tasks (Android only)
      if (Platform.isAndroid) {
        await Workmanager().initialize(
          backgroundTaskCallback,
          isInDebugMode: kDebugMode,
        );
      } else if (Platform.isIOS) {
        // iOS background processing is handled differently
        debugPrint('Background service: iOS initialization - using app lifecycle events');
      }
    } catch (e) {
      debugPrint('Background service initialization error: $e');
      // Continue without background service if initialization fails
    }
  }

  /// Start the background service
  static Future<bool> startService() async {
    try {
      // Only register periodic tasks on Android
      // iOS has different background processing limitations
      if (Platform.isAndroid) {
        await Workmanager().registerPeriodicTask(
          'com.wahda_bank.emailCheck',
          'emailBackgroundCheck',
          frequency: const Duration(minutes: 15),
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
          existingWorkPolicy: ExistingWorkPolicy.replace,
          backoffPolicy: BackoffPolicy.linear,
          backoffPolicyDelay: const Duration(minutes: 5),
        );
      } else if (Platform.isIOS) {
        // For iOS, we'll use app lifecycle events instead of periodic tasks
        // iOS has strict background processing limitations
        debugPrint('Background service: iOS detected, using app lifecycle events');
      }

      // Store service state
      final storage = GetStorage();
      await storage.write(keyBackgroundServiceEnabled, true);
      await storage.write(keyBackgroundServiceLastRun, DateTime.now().toIso8601String());

      return true;
    } catch (e) {
      debugPrint('Background service error: $e');
      // Gracefully handle the error and continue without background service
      final storage = GetStorage();
      await storage.write(keyBackgroundServiceEnabled, false);
      return false;
    }
  }

  /// Stop the background service
  static Future<bool> stopService() async {
    try {
      // Cancel all tasks (Android only)
      if (Platform.isAndroid) {
        await Workmanager().cancelAll();
      }

      // Store service state
      final storage = GetStorage();
      await storage.write(keyBackgroundServiceEnabled, false);

      return true;
    } catch (e) {
      debugPrint('Background service stop error: $e');
      // Still mark as disabled even if cancellation fails
      final storage = GetStorage();
      await storage.write(keyBackgroundServiceEnabled, false);
      return false;
    }
  }

  /// Check if the background service is enabled
  static Future<bool> isServiceEnabled() async {
    final storage = GetStorage();
    return storage.read<bool>(keyBackgroundServiceEnabled) ?? false;
  }

  /// Background task callback for Workmanager
  @pragma('vm:entry-point')
  static void backgroundTaskCallback() {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    Workmanager().executeTask((taskName, inputData) async {
      try {
        // Initialize required services
        await GetStorage.init();
        await SQLiteDatabaseHelper.instance.database;
        await NotificationService.instance.setup();

        // Show notification that we're checking for emails
        NotificationService.instance.showFlutterNotification(
          "Wahda Bank",
          "Checking for new mail...",
          {},
          notificationId,
        );

        // Check for new emails
        await EmailNotificationService.instance.initialize();
        await EmailNotificationService.instance.checkForNewMessages();

        // Update last run timestamp
        final storage = GetStorage();
        await storage.write(keyBackgroundServiceLastRun, DateTime.now().toIso8601String());

        // Remove the checking notification
        await NotificationService.instance.plugin.cancel(notificationId);

        return true;
      } catch (e) {
        if (kDebugMode) {
          print('Background task error: $e');
        }
        return false;
      }
    });
  }

  /// Check for new emails (legacy method, kept for compatibility)
  static Future<void> checkForNewMail([bool showNotifications = true]) async {
    await NotificationService.instance.setup();
    await GetStorage.init();
    await SQLiteDatabaseHelper.instance.database;

    if (showNotifications) {
      NotificationService.instance.showFlutterNotification(
        "Wahda Bank",
        "Checking for new mail...",
        {},
        notificationId,
      );
    }

    await EmailNotificationService.instance.initialize();
    await EmailNotificationService.instance.checkForNewMessages();

    if (showNotifications) {
      await NotificationService.instance.plugin.cancel(notificationId);
    }
  }

  /// Schedule a non-blocking backfill of derived fields for all known mailboxes.
  /// This runs in small DB batches to avoid UI jank and does not require network.
  /// Safe to call at app startup after services are initialized.
  static void scheduleDerivedFieldsBackfill({
    int perMailboxLimit = 5000,
    int batchSize = 800,
    Duration pauseBetweenBatches = const Duration(milliseconds: 30),
  }) {
    // Fire and forget; do not block startup
    // ignore: discarded_futures
    Future(() async {
      final endTrace = PerfTracer.begin('background.backfillAllMailboxes', args: {
        'perMailboxLimit': perMailboxLimit,
        'batchSize': batchSize,
      });
      try {
        final mailService = MailService.instance;
        // Try to get mailboxes either from controller or from client
        List<Mailbox> mailboxes = [];
        try {
          if (Get.isRegistered<MailBoxController>()) {
            mailboxes = List<Mailbox>.from(Get.find<MailBoxController>().mailboxes);
          }
        } catch (_) {}
        if (mailboxes.isEmpty) {
          try {
            mailboxes = List<Mailbox>.from(mailService.client.mailboxes ?? const []);
          } catch (_) {}
        }
        if (mailboxes.isEmpty) {
          if (kDebugMode) {
            print('📧 Backfill skipped: no mailboxes available');
          }
          return;
        }
        for (final mb in mailboxes) {
          try {
            // Initialize storage for this mailbox (without network)
            final storage = SQLiteMailboxMimeStorage(
              mailAccount: mailService.account,
              mailbox: mb,
            );
            await storage.init();

            int processed = 0;
            while (processed < perMailboxLimit) {
              final updated = await storage.backfillDerivedFields(maxRows: batchSize);
              if (updated <= 0) break;
              processed += updated;
              await Future.delayed(pauseBetweenBatches);
            }
            if (kDebugMode) {
              print('📧 Backfill mailbox ${mb.name}: processed $processed rows');
            }
          } catch (e) {
            if (kDebugMode) {
              print('📧 Backfill error for mailbox ${mb.name}: $e');
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('📧 Global backfill error: $e');
        }
      } finally {
        try { endTrace(); } catch (_) {}
      }
    });
  }

  /// Optimize battery usage by requesting battery optimization exemption
  static Future<void> optimizeBatteryUsage() async {
    await EmailNotificationService.instance.requestBatteryOptimizationExemption();
  }

  /// Add next UID for inbox (legacy method, kept for compatibility)
  Future<void> addNextUidFor() async {
    try {
      // This functionality is now handled by EmailNotificationService
      await EmailNotificationService.instance.initialize();
      await EmailNotificationService.instance.checkForNewMessages();
    } catch (e, s) {
      if (kDebugMode) {
        print('Error while getting Inbox.nextUids for : $e $s');
      }
    }
  }
}
