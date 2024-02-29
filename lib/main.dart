import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wahda_bank/app.dart';
import 'package:wahda_bank/services/bg_service.dart';
import 'package:workmanager/workmanager.dart';
import 'models/hive_mime_storage.dart';

Future main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await GetStorage.init();
  await Hive.initFlutter();
  Hive.registerAdapter(StorageMessageIdAdapter());
  Hive.registerAdapter(StorageMessageEnvelopeAdapter());
  // BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
  // initBgService();
  await Workmanager().initialize(
    backgroundFetchHeadlessTask,
    isInDebugMode: true,
  );

  runApp(const MyApp());
  FlutterNativeSplash.remove();
}
