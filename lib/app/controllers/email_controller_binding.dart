import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/auth_controller.dart';
import 'package:wahda_bank/app/controllers/background_task_controller.dart';
import 'package:wahda_bank/app/controllers/contact_controller.dart';
import 'package:wahda_bank/app/controllers/email_fetch_controller.dart';
import 'package:wahda_bank/app/controllers/email_operation_controller.dart';
import 'package:wahda_bank/app/controllers/email_storage_controller.dart';
import 'package:wahda_bank/app/controllers/email_ui_state_controller.dart';
import 'package:wahda_bank/app/controllers/mailbox_list_controller.dart';
import 'package:wahda_bank/app/controllers/selection_controller.dart';
import 'package:wahda_bank/app/controllers/mail_count_controller.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';

/// Binding class for initializing all email-related controllers
class EmailControllerBinding extends Bindings {
  @override
  void dependencies() {
    // Initialize controllers in the correct order to ensure dependencies are available

    // 0. First ensure mail service is available
    Get.put(MailService.instance, permanent: true);

    // 1. Initialize background task controller for queuing operations
    Get.put<BackgroundTaskController>(BackgroundTaskController(), permanent: true);

    // 2. Initialize storage controller
    Get.put<EmailStorageController>(EmailStorageController(), permanent: true);

    // 3. Initialize mailbox list controller which depends on storage
    Get.put<MailboxListController>(MailboxListController(), permanent: true);

    // 4. Initialize email fetch controller which depends on mailbox list and storage
    Get.put<EmailFetchController>(EmailFetchController(), permanent: true);

    // 5. Initialize email operation controller which depends on fetch controller
    Get.put<EmailOperationController>(EmailOperationController(), permanent: true);

    // 6. Initialize contact controller
    Get.put<ContactController>(ContactController(), permanent: true);

    // 7. Initialize UI state controller which depends on all other controllers
    Get.put<EmailUiStateController>(EmailUiStateController(), permanent: true);

    // 8. Initialize selection controller for message selection
    Get.put<SelectionController>(SelectionController(), permanent: true);

    // 9. Initialize mail count controller for unread counts
    Get.put<MailCountController>(MailCountController(), permanent: true);

    // 10. Initialize compose controller for email composition
    Get.lazyPut<ComposeController>(() => ComposeController(), fenix: true);

    // 11. Initialize auth controller
    Get.put<AuthController>(AuthController(), permanent: true);

    // 12. Initialize auth controller
    Get.put<SettingController>(SettingController(), permanent: true);

    // Wait for all controllers to be initialized
    _ensureInitialization();
  }

  /// Ensures all controllers are properly initialized
  void _ensureInitialization() {
    // Access each controller to ensure they're initialized
    Get.find<BackgroundTaskController>();
    Get.find<EmailStorageController>();
    Get.find<MailboxListController>();
    Get.find<EmailFetchController>();
    Get.find<EmailOperationController>();
    Get.find<ContactController>();
    Get.find<EmailUiStateController>();
    Get.find<SelectionController>();
    Get.find<MailCountController>();
    Get.find<AuthController>();
    // Note: ComposeController is lazy loaded, so we don't force initialization here
  }

  /// Static method for initializing all controllers
  static Future<void> initializeControllers() async {
    // Use put instead of lazyPut to ensure immediate initialization
    EmailControllerBinding().dependencies();

    // Allow time for controllers to initialize
    await Future.delayed(const Duration(milliseconds: 100));
  }
}
