import 'package:get/get.dart';

import '../controllers/mail_count_controller.dart';
import '../controllers/mailbox_controller.dart';
import '../controllers/selection_controller.dart';
import '../controllers/settings_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<MailBoxController>(
      () => MailBoxController(),
      fenix: true,
    );

    Get.lazyPut<SelectionController>(
      () => SelectionController(),
    );
    Get.lazyPut<SettingController>(
      () => SettingController(),
    );
    Get.lazyPut(() => MailCountController());
  }
}
