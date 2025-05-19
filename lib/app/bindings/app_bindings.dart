// import 'package:get/get.dart';
// import 'package:wahda_bank/services/edge_case_handler.dart';
// import 'package:wahda_bank/services/email_deletion_manager.dart';
// import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
// import 'package:wahda_bank/app/controllers/selection_controller.dart';
// import 'package:wahda_bank/models/sqlite_mime_storage.dart';
//
// class AppBindings extends Bindings {
//   @override
//   void dependencies() {
//     // Register existing controllers and services
//     Get.put(MailBoxController(), permanent: true);
//     Get.put(SelectionController(), permanent: true);
//     Get.put(SqliteMimeStorage(), permanent: true);
//
//     // Register new enhanced services
//     Get.put(EdgeCaseHandler(), permanent: true);
//     Get.put(EmailDeletionManager(
//       mailboxController: Get.find<MailBoxController>(),
//       selectionController: Get.find<SelectionController>(),
//     ), permanent: true);
//   }
// }
