import 'dart:async';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/services/internet_service.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/models/sqlite_mailbox_storage.dart';
import 'package:wahda_bank/views/settings/data/swap_data.dart';

import 'background_task_controller.dart';
import 'email_fetch_controller.dart';
import 'email_storage_controller.dart';
import 'mailbox_list_controller.dart';

/// Controller responsible for performing operations on emails
/// (mark as read, delete, move, flag, etc.)
class EmailOperationController extends GetxController {
  final Logger logger = Logger();

  // Services and controllers
  late MailService mailService;
  final settingController = Get.find<SettingController>();

  // For undo delete operation
  DeleteResult? deleteResult;
  Map<Mailbox, List<MimeMessage>> deletedMessages = {};

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
    if (Get.isRegistered<EmailStorageController>()) {
      return Get.find<EmailStorageController>().getMailboxStorage(mailbox);
    }
    throw Exception("EmailStorageController not registered");
  }

  /// Get mail service instance
  MailService getMailService() {
    return mailService;
  }

  /// Handle left-to-right swipe action based on settings
  void ltrTap(MimeMessage message, Mailbox mailBox) {
    final ltrAction = getSwapActionFromString(settingController.swipeGesturesLTR.value);
    _handleSwipeAction(ltrAction, message, mailBox);
  }

  /// Handle right-to-left swipe action based on settings
  void rtlTap(MimeMessage message, Mailbox mailBox) {
    final rtlAction = getSwapActionFromString(settingController.swipeGesturesRTL.value);
    _handleSwipeAction(rtlAction, message, mailBox);
  }

  /// Handle swipe action based on the swap action
  void _handleSwipeAction(SwapAction swapAction, MimeMessage message, Mailbox mailBox) {
    switch (swapAction) {
      case SwapAction.delete:
        deleteMails([message], mailBox);
        break;
      case SwapAction.archive:
        if (Get.isRegistered<MailboxListController>()) {
          final mailboxController = Get.find<MailboxListController>();
          final archiveBox = mailboxController.getMailboxByType(isArchive: true);
          if (archiveBox != null) {
            moveMails([message], mailBox, archiveBox);
          } else {
            Get.showSnackbar(
              const GetSnackBar(
                message: 'Archive mailbox not found',
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
        break;
      case SwapAction.readUnread:
      // Toggle read/unread status
        markAsReadUnread([message], mailBox, !message.isSeen);
        break;
      case SwapAction.toggleFlag:
        updateFlag([message], mailBox);
        break;
      case SwapAction.markAsJunk:
        if (Get.isRegistered<MailboxListController>()) {
          final mailboxController = Get.find<MailboxListController>();
          final junkBox = mailboxController.getMailboxByType(isJunk: true);
          if (junkBox != null) {
            moveMails([message], mailBox, junkBox);
          } else {
            Get.showSnackbar(
              const GetSnackBar(
                message: 'Junk mailbox not found',
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
        break;
    }
  }

  /// Show dialog to select destination mailbox for move operation
  void _showMoveDialog(MimeMessage message, Mailbox sourceMailbox) {
    if (Get.isRegistered<MailboxListController>()) {
      final mailboxController = Get.find<MailboxListController>();
      final mailboxes = mailboxController.sortedMailBoxes;

      Get.dialog(
        AlertDialog(
          title: const Text('Move to'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: mailboxes.length,
              itemBuilder: (context, index) {
                final mailbox = mailboxes[index];
                // Skip current mailbox
                if (mailbox.encodedPath == sourceMailbox.encodedPath) {
                  return const SizedBox.shrink();
                }
                return ListTile(
                  title: Text(mailbox.name),
                  onTap: () {
                    moveMails([message], sourceMailbox, mailbox);
                    Get.back();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }
  }

  /// Mark messages as read or unread
  Future<void> markAsReadUnread(List<MimeMessage> messages, Mailbox box,
      [bool isSeen = true]) async {
    // Create a copy of messages to avoid modifying the original list
    final updatedMessages = <MimeMessage>[];

    for (var message in messages) {
      // Only update if the status is changing
      if (message.isSeen != isSeen) {
        message.isSeen = isSeen;
        updatedMessages.add(message);

        // Update storage immediately
        if (Get.isRegistered<EmailStorageController>()) {
          final storageController = Get.find<EmailStorageController>();
          if (storageController.hasStorageForMailbox(box)) {
            _queueOperation(() async {
              await storageController.updateMessageFlags(message, box);
            });
          }
        }
      }
    }

    // If no messages were actually updated, return early
    if (updatedMessages.isEmpty) return;

    // Update the emails list
    if (Get.isRegistered<EmailFetchController>()) {
      final fetchController = Get.find<EmailFetchController>();
      if (fetchController.emails[box] != null) {
        for (var message in updatedMessages) {
          final index = fetchController.emails[box]!.indexWhere((m) => m.uid == message.uid);
          if (index >= 0) {
            fetchController.emails[box]![index] = message;
          }
        }
        fetchController.emails.refresh(); // Force UI update
        fetchController.notifyEmailsChanged(); // Update stream with debouncing
      }
    }

    // Update on server if connected
    if (InternetService.instance.connected && mailService.client.isConnected) {
      _queueOperation(() async {
        for (var message in updatedMessages) {
          try {
            await mailService.client.flagMessage(message, isSeen: isSeen);
          } catch (e) {
            logger.e("Error updating message flags on server: $e");
            // Continue with other messages even if one fails
          }
        }
      });
    }
  }

  /// Delete messages
  Future<void> deleteMails(List<MimeMessage> messages, Mailbox mailbox) async {
    if (messages.isEmpty) return;

    // Store deleted messages for potential undo
    if (deletedMessages[mailbox] == null) {
      deletedMessages[mailbox] = [];
    }
    deletedMessages[mailbox]!.addAll(messages);

    // Remove from emails list immediately for real-time UI update
    if (Get.isRegistered<EmailFetchController>()) {
      final fetchController = Get.find<EmailFetchController>();
      if (fetchController.emails[mailbox] != null) {
        for (var message in messages) {
          fetchController.emails[mailbox]!.removeWhere((m) => m.uid == message.uid);
        }
        fetchController.emails.refresh(); // Force UI update
        fetchController.notifyEmailsChanged(); // Update stream with debouncing
      }
    }

    // Delete from storage in background
    _queueOperation(() async {
      for (var message in messages) {
        if (Get.isRegistered<EmailStorageController>()) {
          final storageController = Get.find<EmailStorageController>();
          if (storageController.hasStorageForMailbox(mailbox)) {
            try {
              await storageController.deleteMessage(message, mailbox);
            } catch (e) {
              logger.e("Error deleting message from storage: $e");
            }
          }
        }
      }
    });

    // Delete on server if connected
    if (mailService.client.isConnected) {
      try {
        deleteResult = await mailService.client.deleteMessages(
          MessageSequence.fromMessages(messages),
          messages: messages,
          expunge: false,
        );

        if (deleteResult != null && deleteResult!.canUndo) {
          Get.showSnackbar(
            GetSnackBar(
              message: 'messages_deleted'.tr,
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 5),
              mainButton: TextButton(
                onPressed: () async {
                  await undoDelete();
                },
                child: Text('undo'.tr),
              ),
            ),
          );
        }
      } catch (e) {
        logger.e("Error deleting messages on server: $e");
        // Show error message
        Get.showSnackbar(
          GetSnackBar(
            message: 'Error deleting messages: ${e.toString()}',
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Undo delete operation
  Future<void> undoDelete() async {
    if (deleteResult != null) {
      try {
        await mailService.client.undoDeleteMessages(deleteResult!);
        deleteResult = null;

        // Restore deleted messages
        for (var mailbox in deletedMessages.keys) {
          if (Get.isRegistered<EmailFetchController>()) {
            final fetchController = Get.find<EmailFetchController>();
            if (fetchController.emails[mailbox] != null) {
              fetchController.emails[mailbox]!.addAll(deletedMessages[mailbox]!);

              // Sort messages by date
              fetchController.emails[mailbox]!.sort((a, b) {
                final dateA = a.decodeDate() ?? DateTime.now();
                final dateB = b.decodeDate() ?? DateTime.now();
                return dateB.compareTo(dateA);
              });

              fetchController.emails.refresh(); // Force UI update
              fetchController.notifyEmailsChanged(); // Update stream with debouncing
            }
          }

          // Restore in storage
          _queueOperation(() async {
            if (Get.isRegistered<EmailStorageController>()) {
              final storageController = Get.find<EmailStorageController>();
              await storageController.saveMessageEnvelopes(deletedMessages[mailbox]!, mailbox);
            }
          });
        }
        deletedMessages.clear();

        // Show success message
        Get.showSnackbar(
          const GetSnackBar(
            message: 'Messages restored',
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        logger.e("Error undoing delete: $e");
        // Show error message
        Get.showSnackbar(
          GetSnackBar(
            message: 'Error restoring messages: ${e.toString()}',
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Move messages between mailboxes
  Future<void> moveMails(List<MimeMessage> messages, Mailbox from, Mailbox to) async {
    if (messages.isEmpty) return;

    // Remove from source mailbox immediately for real-time UI update
    if (Get.isRegistered<EmailFetchController>()) {
      final fetchController = Get.find<EmailFetchController>();
      if (fetchController.emails[from] != null) {
        for (var message in messages) {
          fetchController.emails[from]!.removeWhere((m) => m.uid == message.uid);
        }
        fetchController.emails.refresh(); // Force UI update
        fetchController.notifyEmailsChanged(); // Update stream with debouncing
      }

      // Add to destination mailbox
      if (fetchController.emails[to] != null) {
        fetchController.emails[to]!.addAll(messages);

        // Sort messages by date
        fetchController.emails[to]!.sort((a, b) {
          final dateA = a.decodeDate() ?? DateTime.now();
          final dateB = b.decodeDate() ?? DateTime.now();
          return dateB.compareTo(dateA);
        });

        fetchController.emails.refresh(); // Force UI update
        fetchController.notifyEmailsChanged(); // Update stream with debouncing
      }
    }

    // Update storage in background
    _queueOperation(() async {
      if (Get.isRegistered<EmailStorageController>()) {
        final storageController = Get.find<EmailStorageController>();
        for (var message in messages) {
          try {
            if (storageController.hasStorageForMailbox(from)) {
              await storageController.deleteMessage(message, from);
            }
            if (storageController.hasStorageForMailbox(to)) {
              await storageController.saveMessageEnvelopes([message], to);
            }
          } catch (e) {
            logger.e("Error moving message in storage: $e");
          }
        }
      }
    });

    // Move on server if connected
    if (mailService.client.isConnected) {
      _queueOperation(() async {
        for (var message in messages) {
          try {
            await mailService.client.moveMessage(message, to);
          } catch (e) {
            logger.e("Error moving message on server: $e");
          }
        }
      });
    }
  }

  /// Update flag status on messages
  Future<void> updateFlag(List<MimeMessage> messages, Mailbox mailbox) async {
    if (messages.isEmpty) return;

    final updatedMessages = <MimeMessage>[];

    for (var message in messages) {
      // Toggle flag status
      message.isFlagged = !message.isFlagged;
      updatedMessages.add(message);

      // Update storage immediately
      if (Get.isRegistered<EmailStorageController>()) {
        final storageController = Get.find<EmailStorageController>();
        if (storageController.hasStorageForMailbox(mailbox)) {
          _queueOperation(() async {
            await storageController.updateMessageFlags(message, mailbox);
          });
        }
      }
    }

    // Update emails list
    if (Get.isRegistered<EmailFetchController>()) {
      final fetchController = Get.find<EmailFetchController>();
      if (fetchController.emails[mailbox] != null) {
        for (var message in updatedMessages) {
          final index = fetchController.emails[mailbox]!.indexWhere((m) => m.uid == message.uid);
          if (index >= 0) {
            fetchController.emails[mailbox]![index] = message;
          }
        }
        fetchController.emails.refresh(); // Force UI update
        fetchController.notifyEmailsChanged(); // Update stream with debouncing
      }
    }

    // Update on server if connected
    if (mailService.client.isConnected) {
      _queueOperation(() async {
        for (var message in updatedMessages) {
          try {
            await mailService.client.flagMessage(
              message,
              isFlagged: message.isFlagged,
            );
          } catch (e) {
            logger.e("Error updating flag on server: $e");
          }
        }
      });
    }
  }

  /// Permanently delete messages (if supported by server)
  Future<void> vanishMails(List<MimeMessage> messages, Mailbox mailbox) async {
    if (messages.isEmpty) return;

    // Remove from emails list immediately for real-time UI update
    if (Get.isRegistered<EmailFetchController>()) {
      final fetchController = Get.find<EmailFetchController>();
      if (fetchController.emails[mailbox] != null) {
        for (var message in messages) {
          fetchController.emails[mailbox]!.removeWhere((m) => m.uid == message.uid);
        }
        fetchController.emails.refresh(); // Force UI update
        fetchController.notifyEmailsChanged(); // Update stream with debouncing
      }
    }

    // Delete from storage in background
    _queueOperation(() async {
      if (Get.isRegistered<EmailStorageController>()) {
        final storageController = Get.find<EmailStorageController>();
        for (var message in messages) {
          if (storageController.hasStorageForMailbox(mailbox)) {
            try {
              await storageController.deleteMessage(message, mailbox);
            } catch (e) {
              logger.e("Error vanishing message from storage: $e");
            }
          }
        }
      }
    });

    // Permanently delete on server if connected
    // Note: Using expunge=true with deleteMessages as a fallback for servers that don't support vanishMessages
    if (mailService.client.isConnected) {
      _queueOperation(() async {
        try {
          // Try to use deleteMessages with expunge=true as a fallback
          await mailService.client.deleteMessages(
            MessageSequence.fromMessages(messages),
            messages: messages,
            expunge: true,
          );
        } catch (e) {
          logger.e("Error permanently deleting messages on server: $e");
        }
      });
    }
  }

  /// Send email
  Future<void> sendMail(MimeMessage message, {Mailbox? sentMailbox, MimeMessage? draftToDelete}) async {
    try {
      await mailService.client.sendMessage(message);

      // Delete draft if provided
      if (draftToDelete != null) {
        await mailService.client.deleteMessage(draftToDelete);
      }

      // Save to Sent mailbox
      Mailbox? sentBox;
      if (sentMailbox != null) {
        sentBox = sentMailbox;
      } else if (Get.isRegistered<MailboxListController>()) {
        // Try to find Sent mailbox
        final mailboxes = Get.find<MailboxListController>().mailboxes;
        sentBox = mailboxes.firstWhereOrNull((element) => element.isSent);
      }

      if (sentBox != null && Get.isRegistered<EmailFetchController>()) {
        final fetchController = Get.find<EmailFetchController>();
        if (fetchController.emails[sentBox] == null) fetchController.emails[sentBox] = [];
        fetchController.emails[sentBox]!.add(message);
        fetchController.emails.refresh();
        fetchController.notifyEmailsChanged();

        if (Get.isRegistered<EmailStorageController>()) {
          final storageController = Get.find<EmailStorageController>();
          if (storageController.hasStorageForMailbox(sentBox)) {
            storageController.saveMessagesInBackground([message], sentBox);
          }
        }
      }

      // Show success message
      Get.showSnackbar(
        const GetSnackBar(
          message: 'Message sent successfully',
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      logger.e("Error sending message: $e");

      // Show error message
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error sending message: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    return;
  }

  // Helper method to queue background operations
  void _queueOperation(Future Function() operation) {
    if (Get.isRegistered<BackgroundTaskController>()) {
      Get.find<BackgroundTaskController>().queueOperation(operation);
    } else {
      // Fallback to direct execution if BackgroundTaskController is not available
      Future.microtask(operation);
    }
  }
}
