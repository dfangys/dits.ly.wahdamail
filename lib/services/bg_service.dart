import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/services/background_service.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void backgroundFetchHeadlessTask() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  Workmanager().executeTask((taskName, inputData) async {
    try {
      // Use the enhanced background service for email checking
      await BackgroundService.checkForNewMail();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Background fetch error: $e');
      }
      return false;
    }
  });
}

/// Initialize background services and tasks
Future<void> initializeBackgroundTasks() async {
  if (Platform.isAndroid || Platform.isIOS) {
    // Initialize Workmanager for periodic tasks
    await Workmanager().initialize(
      backgroundFetchHeadlessTask,
      isInDebugMode: kDebugMode,
    );
    
    // Initialize enhanced background service
    await BackgroundService.initializeService();
    
    // Start background service if enabled
    final isEnabled = await BackgroundService.isServiceEnabled();
    if (!isEnabled) {
      await BackgroundService.startService();
    }
  }
}

/// Register for periodic background email checks
Future<void> registerPeriodicEmailChecks() async {
  if (Platform.isAndroid || Platform.isIOS) {
    // Cancel any existing tasks
    await Workmanager().cancelAll();
    
    // Register periodic task
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
    
    if (kDebugMode) {
      print('Registered periodic email checks');
    }
  }
}

/// Request necessary permissions for background operation
Future<void> requestBackgroundPermissions() async {
  // Request battery optimization exemption
  await BackgroundService.optimizeBatteryUsage();
}
