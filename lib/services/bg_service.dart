import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:wahda_bank/services/background_service.dart';
import 'package:wahda_bank/services/notifications_service.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void backgroundFetchHeadlessTask() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  Workmanager().executeTask((taskName, inputData) async {
    await NotificationService.instance.setup();
    NotificationService.instance.showFlutterNotification(
      "Wahda Bank",
      "Checking for new mail...",
      {},
      888,
    );
    await BackgroundService.checkForNewMail();
    await NotificationService.instance.plugin.cancel(888);
    return true;
  });
}
