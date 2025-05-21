// lib/main.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/app.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/models/sqlite_mime_storage.dart';
import 'package:wahda_bank/services/bg_service.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/services/notifications_service.dart';
import 'package:workmanager/workmanager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1️⃣ Persisted key/value store
  await GetStorage.init();

  // 2️⃣ Fully initialize MailService BEFORE runApp
  final mailOk = await MailService.instance.init();
  if (!mailOk) {
    // TODO: show an error or fallback UI
  }

  // 3️⃣ Global settings
  Get.put<SettingController>(SettingController(), permanent: true);

  // 4️⃣ Notifications
  await NotificationService.instance.setup();

  // 5️⃣ SQLite MIME storage (warm up DB)
  await SqliteMimeStorage.instance.database;

  // 6️⃣ Workmanager / background fetch
  await Workmanager().initialize(
    backgroundFetchHeadlessTask,
    isInDebugMode: false,
  );

  // 7️⃣ Any other native background service
  await BgService.instance.initialize();

  // 8️⃣ Finally, launch your app with your binding
  runApp(const MyApp());
}