import 'package:background_fetch/background_fetch.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wahda_bank/app.dart';

import 'models/hive_mime_storage.dart';
import 'services/background_service.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  await Hive.initFlutter();
  Hive.registerAdapter(StorageMessageIdAdapter());
  Hive.registerAdapter(StorageMessageEnvelopeAdapter());
  BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
  runApp(const MyApp());
}
