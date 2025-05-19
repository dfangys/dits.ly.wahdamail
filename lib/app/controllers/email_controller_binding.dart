import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/auth_controller.dart';
import 'package:wahda_bank/app/controllers/background_task_controller.dart';
import 'package:wahda_bank/app/controllers/contact_controller.dart';
import 'package:wahda_bank/app/controllers/email_fetch_controller.dart';
import 'package:wahda_bank/app/controllers/email_operation_controller.dart';
import 'package:wahda_bank/app/controllers/email_storage_controller.dart';
import 'package:wahda_bank/app/controllers/email_ui_state_controller.dart';
import 'package:wahda_bank/app/controllers/mailbox_list_controller.dart';

/// Binding class for initializing all email-related controllers
class EmailControllerBinding extends Bindings {
  @override
  void dependencies() {
    // Initialize controllers in the correct order to ensure dependencies are available

    // 1. First initialize background task controller for queuing operations
    Get.lazyPut<BackgroundTaskController>(() => BackgroundTaskController(), fenix: true);

    // 2. Initialize storage controller
    Get.lazyPut<EmailStorageController>(() => EmailStorageController(), fenix: true);

    // 3. Initialize mailbox list controller
    Get.lazyPut<MailboxListController>(() => MailboxListController(), fenix: true);

    // 4. Initialize email fetch controller
    Get.lazyPut<EmailFetchController>(() => EmailFetchController(), fenix: true);

    // 5. Initialize email operation controller
    Get.lazyPut<EmailOperationController>(() => EmailOperationController(), fenix: true);

    // 6. Initialize contact controller
    Get.lazyPut<ContactController>(() => ContactController(), fenix: true);

    // 7. Initialize UI state controller
    Get.lazyPut<EmailUIStateController>(() => EmailUIStateController(), fenix: true);

    // 8. Initialize auth controller
    Get.lazyPut<AuthController>(() => AuthController(), fenix: true);
  }

  /// Static method for initializing all controllers
  static void initializeControllers() {
    EmailControllerBinding().dependencies();
  }
}
