import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
// import 'package:hive_flutter/hive_flutter.dart';
import 'package:wahda_bank/app.dart';
import 'package:wahda_bank/services/background_service.dart';
import 'package:wahda_bank/services/notifications_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:wahda_bank/models/sqlite_database_helper.dart';
import 'package:wahda_bank/services/offline_http_server.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  await NotificationService.instance.setup();

  // Initialize SQLite database
  await SQLiteDatabaseHelper.instance.database;

  // Start local offline HTTP server (for non-iOS WebView rendering)
  try {
    final srv = await OfflineHttpServer.instance.start();
    debugPrint('OfflineHttpServer started on 127.0.0.1:$srv');
  } catch (e) {
    debugPrint('OfflineHttpServer start error: $e');
  }

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
