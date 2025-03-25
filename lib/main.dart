import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wahda_bank/app.dart';
import 'package:wahda_bank/services/bg_service.dart';
import 'package:wahda_bank/services/notifications_service.dart';
import 'package:workmanager/workmanager.dart';
import 'models/hive_mime_storage.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  await NotificationService.instance.setup();

  await Hive.initFlutter();
  Hive.registerAdapter(StorageMessageIdAdapter());
  Hive.registerAdapter(StorageMessageEnvelopeAdapter());

  await Workmanager().initialize(
    backgroundFetchHeadlessTask,
    isInDebugMode: false, // kDebugMode,
  );
  runApp(const MyApp());
}
