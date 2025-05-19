// import 'dart:async';
// import 'package:wahda_bank/app/controllers/email_storage_controller.dart';
// import 'package:wahda_bank/models/sqlite_mailbox_storage.dart';
//
// /// This extension adds helper methods to EmailStorageController
// extension EmailStorageControllerExtension on EmailStorageController {
//   /// Initializes storage for a mailbox if it doesn't exist
//   void initializeMailboxStorage(Mailbox mailbox) {
//     if (mailboxStorage[mailbox] == null) {
//       // Create a new storage for this mailbox
//       final storage = SqliteMailboxStorage(mailbox, mailService);
//       mailboxStorage[mailbox] = storage;
//
//       // Initialize the storage
//       storage.initialize();
//
//       logger.d("Initialized storage for mailbox: ${mailbox.name}");
//     }
//   }
// }
