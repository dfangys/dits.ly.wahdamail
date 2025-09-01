import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
// import 'package:hive_flutter/hive_flutter.dart';
import 'package:wahda_bank/app.dart';
import 'package:wahda_bank/services/background_service.dart';
import 'package:wahda_bank/services/notifications_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:wahda_bank/models/sqlite_database_helper.dart';
import 'package:wahda_bank/services/offline_http_server.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/infrastructure/api/mailsys_api_client.dart';
import 'package:wahda_bank/config/api_config.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Swallow transient MailException from IMAP event handlers to avoid app crashes
  // when servers respond with BAD for an intermediate FETCH range.
  // We still log the error for diagnostics.
  FlutterError.onError = (FlutterErrorDetails details) {
    try {
      if (details.exception is MailException) {
        debugPrint('Ignored MailException (global): ${details.exception}');
        return; // handled
      }
    } catch (_) {}
    FlutterError.dumpErrorToConsole(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    if (error is MailException) {
      debugPrint('Ignored MailException (dispatcher): $error');
      return true; // handled
    }
    return false;
  };

  await GetStorage.init();

  await NotificationService.instance.setup();

  // Configure MailSys API client early (pre-auth token & base URL)
  try {
    final api = Get.put(MailsysApiClient(), permanent: true);
    await api.configure(
      baseUrl: ApiConfig.baseUrl,
      appToken: ApiConfig.appToken,
    );
  } catch (e) {
    debugPrint('MailsysApiClient configure error: $e');
  }

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
