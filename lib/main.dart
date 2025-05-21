import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/app.dart';
import 'package:wahda_bank/services/bg_service.dart';
import 'package:wahda_bank/services/notifications_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:wahda_bank/models/sqlite_mime_storage.dart';

import 'app/controllers/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  Get.put<SettingController>(SettingController(), permanent: true);

  await NotificationService.instance.setup();

  // ✅ Initialize SQLite storage for MIME
  await SqliteMimeStorage.instance.database;

  // ✅ Initialize background service
  await Workmanager().initialize(
    backgroundFetchHeadlessTask,
    isInDebugMode: false, // or true during dev
  );

  runApp(const MyApp());
}