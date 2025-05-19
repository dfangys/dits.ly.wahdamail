import 'dart:async';
import 'package:enough_mail/enough_mail.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:wahda_bank/models/sqlite_mailbox_storage.dart';
import 'package:wahda_bank/services/mail_service.dart';

import 'background_task_controller.dart';
import 'email_fetch_controller.dart';

/// Controller responsible for managing local storage of emails
class EmailStorageController extends GetxController {
  final Logger logger = Logger();

  // Storage for each mailbox
  final RxMap<Mailbox, SqliteMailboxStorage> mailboxStorage =
      <Mailbox, SqliteMailboxStorage>{}.obs;

  // Services
  late MailService mailService;

  @override
  void onInit() async {
    try {
      mailService = MailService.instance;
      super.onInit();
    } catch (e) {
      logger.e(e);
    }
  }

  /// Get mailbox storage for a specific mailbox
  SqliteMailboxStorage getMailboxStorage(Mailbox mailbox) {
    if (mailboxStorage[mailbox] == null) {
      throw Exception("Storage not initialized for mailbox ${mailbox.name}");
    }
    return mailboxStorage[mailbox]!;
  }

  /// Check if storage exists for a mailbox
  bool hasStorageForMailbox(Mailbox mailbox) {
    return mailboxStorage[mailbox] != null;
  }

  /// Initialize storage for a mailbox
  Future<void> initializeMailboxStorage(Mailbox mailbox) async {
    if (mailboxStorage[mailbox] != null) return;

    try {
      // Create and initialize storage for this mailbox
      mailboxStorage[mailbox] = SqliteMailboxStorage(
        mailAccount: mailService.account,
        mailbox: mailbox,
      );
      await mailboxStorage[mailbox]!.init();

      // Set up listener for storage updates
      mailboxStorage[mailbox]!.messageStream.listen((messages) {
        // Notify EmailFetchController about updated messages
        if (Get.isRegistered<EmailFetchController>()) {
          final fetchController = Get.find<EmailFetchController>();

          // Always sort messages by date (newest first)
          messages.sort((a, b) {
            final dateA = a.decodeDate() ?? DateTime.now();
            final dateB = b.decodeDate() ?? DateTime.now();
            return dateB.compareTo(dateA);
          });

          fetchController.emails[mailbox] = messages;
          fetchController.emails.refresh(); // Force UI update
          fetchController.notifyEmailsChanged(); // Update stream with debouncing

          // Update unread count
          fetchController.updateUnreadCount(mailbox);
        }
      });
    } catch (e) {
      logger.e("Error initializing storage for mailbox ${mailbox.name}: $e");
    }
  }

  /// Save message envelopes to storage
  Future<void> saveMessageEnvelopes(List<MimeMessage> messages, Mailbox mailbox) async {
    if (messages.isEmpty) return;

    try {
      if (mailboxStorage[mailbox] == null) {
        await initializeMailboxStorage(mailbox);
      }

      await mailboxStorage[mailbox]!.saveMessageEnvelopes(messages);
    } catch (e) {
      logger.e("Error saving messages to storage: $e");
    }
  }

  /// Save messages in background to prevent UI blocking
  void saveMessagesInBackground(List<MimeMessage> messages, Mailbox mailbox) {
    if (messages.isEmpty) return;

    // Use background task controller if available
    if (Get.isRegistered<BackgroundTaskController>()) {
      Get.find<BackgroundTaskController>().queueOperation(() async {
        await saveMessageEnvelopes(messages, mailbox);
      });
    } else {
      // Fallback to direct save
      Future.microtask(() async {
        await saveMessageEnvelopes(messages, mailbox);
      });
    }
  }

  /// Update message flags in storage
  Future<void> updateMessageFlags(MimeMessage message, Mailbox mailbox) async {
    try {
      if (mailboxStorage[mailbox] == null) {
        await initializeMailboxStorage(mailbox);
      }

      await mailboxStorage[mailbox]!.updateMessageFlags(message);
    } catch (e) {
      logger.e("Error updating message flags in storage: $e");
    }
  }

  /// Delete message from storage
  Future<void> deleteMessage(MimeMessage message, Mailbox mailbox) async {
    try {
      if (mailboxStorage[mailbox] == null) {
        await initializeMailboxStorage(mailbox);
      }

      await mailboxStorage[mailbox]!.deleteMessage(message);
    } catch (e) {
      logger.e("Error deleting message from storage: $e");
    }
  }

  /// Load message envelopes from storage
  Future<List<MimeMessage>> loadMessageEnvelopes(Mailbox mailbox, MessageSequence sequence) async {
    try {
      if (mailboxStorage[mailbox] == null) {
        await initializeMailboxStorage(mailbox);
      }

      final messages = await mailboxStorage[mailbox]!.loadMessageEnvelopes(sequence);
      return messages ?? [];
    } catch (e) {
      logger.e("Error loading messages from storage: $e");
      return [];
    }
  }

  /// Load new messages since a specific UID
  Future<List<MimeMessage>> loadNewMessages(Mailbox mailbox, int lastUid) async {
    try {
      if (mailboxStorage[mailbox] == null) {
        await initializeMailboxStorage(mailbox);
      }

      final messages = await mailboxStorage[mailbox]!.loadNewMessages(lastUid);
      return messages ?? [];
    } catch (e) {
      logger.e("Error loading new messages from storage: $e");
      return [];
    }
  }

  /// Clean up storage when account is removed
  Future<void> onAccountRemoved() async {
    for (var mailbox in mailboxStorage.keys) {
      try {
        await mailboxStorage[mailbox]!.onAccountRemoved();
      } catch (e) {
        logger.e("Error removing storage for mailbox ${mailbox.name}: $e");
      }
    }

    mailboxStorage.clear();
    return;
  }
}
