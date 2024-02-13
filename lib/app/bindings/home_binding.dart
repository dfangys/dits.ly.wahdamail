import 'package:get/get.dart';

import '../controllers/mailbox_controller.dart';
import '../controllers/settings_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MailBoxController>(
      () => MailBoxController(),
      fenix: true,
    );
    Get.lazyPut<SettingController>(
      () => SettingController(),
    );
  }
}
