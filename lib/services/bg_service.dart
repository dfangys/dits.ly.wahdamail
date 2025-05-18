import 'package:flutter/material.dart';
import 'package:wahda_bank/services/background_service.dart';
import 'package:wahda_bank/services/email_notification_service.dart';
import 'package:wahda_bank/services/notifications_service.dart';
import 'package:workmanager/workmanager.dart';
import 'dart:ui';

@pragma('vm:entry-point')
void backgroundFetchHeadlessTask() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  Workmanager().executeTask((taskName, inputData) async {
    await NotificationService.instance.setup();

    // Start IMAP IDLE if it's a background service initialization task
    if (taskName == 'startImapIdleTask') {
      await EmailNotificationService.instance.connectAndListen();
      return true;
    }

    // For regular mail checking tasks
    NotificationService.instance.showFlutterNotification(
      "Wahda Bank",
      "Checking for new mail...",
      {},
      888,
    );

    // Try to use IMAP IDLE first, fall back to polling check if needed
    final idleStarted = await EmailNotificationService.instance.connectAndListen();
    if (!idleStarted) {
      await BackgroundService.checkForNewMail();
    }

    await NotificationService.instance.plugin.cancel(888);
    return true;
  });
}
