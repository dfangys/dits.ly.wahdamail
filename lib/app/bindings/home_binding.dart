// lib/app/bindings/home_binding.dart

import 'package:get/get.dart';
import 'package:wahda_bank/models/sqlite_mime_storage.dart';
import 'package:wahda_bank/app/controllers/email_controller_binding.dart';
import 'package:wahda_bank/app/controllers/selection_controller.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/app/controllers/mail_count_controller.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    // 1️⃣ Ensure local SQLite storage is warmed up
    Get.putAsync<SqliteMimeStorage>(
          () async {
        final storage = SqliteMimeStorage.instance;
        await storage.database;
        return storage;
      },
      permanent: true,
    ).then((_) {
      // 2️⃣ Guarantee all email controllers are bound
      EmailControllerBinding().dependencies();

      // 3️⃣ Screen-specific controllers
      Get.lazyPut<SelectionController>(() => SelectionController(), fenix: true);
      Get.lazyPut<SettingController>(()   => SettingController(),   fenix: true);
      Get.lazyPut<MailCountController>(()   => MailCountController(),   fenix: true);
      Get.lazyPut<ComposeController>(()     => ComposeController(),     fenix: true);
    });
  }
}