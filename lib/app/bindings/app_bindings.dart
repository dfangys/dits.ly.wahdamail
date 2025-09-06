import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mail_count_controller.dart';

/// AppBindings: temporary shim to ensure MailCountController is available app-wide.
/// TODO(P12.4c): Remove this shim once MailCountController is replaced by VM/use-case.
class AppBindings extends Bindings {
  @override
  void dependencies() {
    // Temporary: will be removed in P12.4c
    if (!Get.isRegistered<MailCountController>()) {
      Get.lazyPut<MailCountController>(() => MailCountController(), fenix: true);
    }
  }
}

