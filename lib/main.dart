import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wahda_bank/app.dart';

import 'models/hive_mime_storage.dart';
import 'services/background_service.dart';

Future main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await Future.delayed(const Duration(seconds: 3));
  FlutterNativeSplash.remove();
  await GetStorage.init();
  await Hive.initFlutter();
  Hive.registerAdapter(StorageMessageIdAdapter());
  Hive.registerAdapter(StorageMessageEnvelopeAdapter());
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
  BackgroundFetch.start().then((int status) {
    if (kDebugMode) {
      print('[BackgroundFetch] start success: $status');
    }
  }).catchError((e) {
    if (kDebugMode) {
      print('[BackgroundFetch] start FAILURE: $e');
    }
  });
  runApp(const MyApp());
}
