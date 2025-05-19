import 'package:get/get.dart';
import 'package:wahda_bank/models/sqlite_mime_storage.dart';

import '../controllers/mail_count_controller.dart';
// import '../controllers/mailbox_controller.dart';
import '../controllers/selection_controller.dart';
import '../controllers/settings_controller.dart';
import 'package:wahda_bank/app/controllers/email_controller_binding.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SelectionController>(() => SelectionController());
    Get.lazyPut<SettingController>(() => SettingController());
    Get.lazyPut<MailCountController>(() => MailCountController());
    EmailControllerBinding().dependencies();

    // 👇 this line is the important change
    Get.putAsync<SqliteMimeStorage>(() async {
      final storage = SqliteMimeStorage.instance;
      await storage.database;          // warm-up
      return storage;
    });
  }

}
