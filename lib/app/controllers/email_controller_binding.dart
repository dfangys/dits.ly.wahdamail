// lib/app/controllers/email_controller_binding.dart

import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/auth_controller.dart';
import 'package:wahda_bank/app/controllers/background_task_controller.dart';
import 'package:wahda_bank/app/controllers/contact_controller.dart';
import 'package:wahda_bank/app/controllers/email_fetch_controller.dart';
import 'package:wahda_bank/app/controllers/email_operation_controller.dart';
import 'package:wahda_bank/app/controllers/email_storage_controller.dart';
import 'package:wahda_bank/app/controllers/email_ui_state_controller.dart';
import 'package:wahda_bank/app/controllers/mail_count_controller.dart';
import 'package:wahda_bank/app/controllers/mailbox_list_controller.dart';
import 'package:wahda_bank/app/controllers/selection_controller.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';

/// This binding runs once at app startup (via initialBinding).
/// MailService has already been init() in main().
class EmailControllerBinding extends Bindings {
  @override
  void dependencies() {
    // 1️⃣ MailService is ready—just put the singleton
    Get.put<MailService>(MailService.instance, permanent: true);

    // 2️⃣ Core background task & storage
    Get.put<BackgroundTaskController>(BackgroundTaskController(), permanent: true);
    Get.put<EmailStorageController>(EmailStorageController(), permanent: true);

    // 3️⃣ Mailbox list & fetch orchestration
    Get.put<MailboxListController>(MailboxListController(), permanent: true);
    Get.put<EmailFetchController>(EmailFetchController(), permanent: true);

    // 4️⃣ Operations & contact sync
    Get.put<EmailOperationController>(EmailOperationController(), permanent: true);
    Get.put<ContactController>(ContactController(), permanent: true);

    // 5️⃣ UI state & selection & counts
    Get.put<EmailUiStateController>(EmailUiStateController(), permanent: true);
    Get.put<SelectionController>(SelectionController(), permanent: true);
    Get.put<MailCountController>(MailCountController(), permanent: true);

    // 6️⃣ Compose (lazy, fenix)
    Get.lazyPut<ComposeController>(() => ComposeController(), fenix: true);

    // 7️⃣ Auth & settings
    Get.put<AuthController>(AuthController(), permanent: true);
    // SettingsController is already put in main()
  }
}