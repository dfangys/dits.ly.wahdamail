import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
// import 'package:hive_flutter/hive_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wahda_bank/app.dart';
import 'package:wahda_bank/services/background_service.dart';
import 'package:wahda_bank/services/notifications_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:wahda_bank/models/sqlite_database_helper.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  await NotificationService.instance.setup();

  // Initialize SQLite database
  await SQLiteDatabaseHelper.instance.database;

  // Initialize Hive for backward compatibility during migration
  // await Hive.initFlutter();

  // Initialize background service with proper error handling
  try {
    // Only initialize Workmanager on Android
    if (Platform.isAndroid) {
      await Workmanager().initialize(
        BackgroundService.backgroundTaskCallback,
        isInDebugMode: true,
      );
    }
  } catch (e) {
    debugPrint('Workmanager initialization error: $e');
    // Continue app startup even if background service fails
  }
  
  runApp(const MyApp());
}
