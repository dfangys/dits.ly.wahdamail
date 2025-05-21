import 'dart:async';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:wahda_bank/models/sqlite_mailbox_storage.dart' show SqliteMailboxStorage;
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/services/internet_service.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/views/settings/data/swap_data.dart';

import 'background_task_controller.dart';
import 'email_fetch_controller.dart';
import 'email_storage_controller.dart';
import 'mailbox_list_controller.dart';
import 'email_ui_state_controller.dart';

/// Controller responsible for performing operations on emails
/// (mark as read, delete, move, flag, etc.)
class EmailOperationController extends GetxController {
  final Logger logger = Logger();

  // Services and controllers
  late MailService mailService;
  late BackgroundTaskController _backgroundTaskController;
  late EmailFetchController _fetchController;
  late EmailStorageController _storageController;
  late MailboxListController _mailboxListController;
  EmailUiStateController? _uiStateController;
  final settingController = Get.find<SettingController>();

  // For undo delete operation
  DeleteResult? deleteResult;
  Map<Mailbox, List<MimeMessage>> deletedMessages = {};

  // Lock to prevent concurrent operations on the same mailbox
  final Map<String, Completer<void>> _operationLocks = {};

  // Operation status tracking
  final RxBool isOperationInProgress = false.obs;
  final RxString currentOperation = ''.obs;

  @override
  void onInit() async {
    try {
      mailService = MailService.instance;

      // Get required controllers
      _backgroundTaskController = Get.find<BackgroundTaskController>();
      _fetchController = Get.find<EmailFetchController>();
      _storageController = Get.find<EmailStorageController>();
      _mailboxListController = Get.find<MailboxListController>();

      // Try to find UI state controller, but don't fail if not available yet
      if (Get.isRegistered<EmailUiStateController>()) {
        _uiStateController = Get.find<EmailUiStateController>();
      }

      // Listen for operation status changes
      ever(isOperationInProgress, (bool value) {
        if (_uiStateController != null) {
          if (value) {
            _uiStateController!.showLoading(currentOperation.value);
          } else {
            _uiStateController!.hideLoading();
          }
        }
      });

      super.onInit();
    } catch (e) {
      logger.e("Error initializing EmailOperationController: $e");
    }
  }

  /// Acquire a lock for a mailbox to prevent concurrent operations
  Future<void> _acquireOperationLock(Mailbox mailbox) async {
    final lockKey = mailbox.encodedPath;
    if (_operationLocks.containsKey(lockKey)) {
      // Wait for existing operation to complete
      await _operationLocks[lockKey]!.future;
    }

    // Create a new lock
    final completer = Completer<void>();
    _operationLocks[lockKey] = completer;
  }

  /// Release a lock for a mailbox
  void _releaseOperationLock(Mailbox mailbox) {
    final lockKey = mailbox.encodedPath;
    if (_operationLocks.containsKey(lockKey)) {
      _operationLocks[lockKey]!.complete();
      _operationLocks.remove(lockKey);
    }
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
        final archiveBox = _mailboxListController.getMailboxByType(isArchive: true);
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
        break;
      case SwapAction.readUnread:
      // Toggle read/unread status
        markAsReadUnread([message], mailBox, !message.isSeen);
        break;
      case SwapAction.toggleFlag:
        updateFlag([message], mailBox);
        break;
      case SwapAction.markAsJunk:
        final junkBox = _mailboxListController.getMailboxByType(isJunk: true);
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
        break;
    }
  }

  /// Show dialog to select destination mailbox for move operation
  void showMoveDialog(MimeMessage message, Mailbox sourceMailbox) {
    final mailboxes = _mailboxListController.sortedMailBoxes;

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

  /// Mark messages as read or unread with batch optimization
  Future<void> markAsReadUnread(List<MimeMessage> messages, Mailbox box,
      [bool isSeen = true]) async {
    if (messages.isEmpty) return;

    // Set operation status
    isOperationInProgress(true);
    currentOperation.value = isSeen ? 'Marking as read...' : 'Marking as unread...';

    // Acquire lock to prevent concurrent operations on the same mailbox
    await _acquireOperationLock(box);

    try {
      // Create a copy of messages to avoid modifying the original list
      final updatedMessages = <MimeMessage>[];

      for (var message in messages) {
        // Only update if the status is changing
        if (message.isSeen != isSeen) {
          // Create a copy of the message to avoid modifying the original
          // In enough_mail 2.1.6, we need to manually copy the message
          final messageCopy = MimeMessage();
          messageCopy.uid = message.uid;
          messageCopy.sequenceId = message.sequenceId;
          messageCopy.flags = message.flags != null ? List<String>.from(message.flags!) : null;
          messageCopy.isSeen = isSeen; // Set the new seen status
          messageCopy.isAnswered = message.isAnswered;
          messageCopy.isFlagged = message.isFlagged;
          final flags = message.flags ?? [];
          if (flags.contains(r'\Draft')) {
            messageCopy.flags ??= [];
            messageCopy.flags!.add(r'\Draft');
          }
          if (flags.contains(r'\Recent')) {
            messageCopy.flags ??= [];
            messageCopy.flags!.add(r'\Recent');
          }

          updatedMessages.add(messageCopy);
        }
      }

      // If no messages were actually updated, return early
      if (updatedMessages.isEmpty) {
        isOperationInProgress(false);
        return;
      }

      // Update the emails list immediately for UI responsiveness
      if (_fetchController.emails[box] != null) {
        for (var message in updatedMessages) {
          final index = _fetchController.emails[box]!.indexWhere((m) => m.uid == message.uid);
          if (index >= 0) {
            // Update the seen status in the original message
            _fetchController.emails[box]![index].isSeen = message.isSeen;
          }
        }

        // Notify about changes
        _fetchController.notifyEmailsChanged(box, UpdateType.update, updatedMessages);
      }

      // Update storage in background
      _backgroundTaskController.queueOperation(() async {
        await _storageController.updateMessageFlagsBatch(updatedMessages, box);
      });

      // Update on server if connected
      if (InternetService.instance.connected && mailService.client.isConnected) {
        _backgroundTaskController.queueOperation(() async {
          try {
            // Ensure the correct mailbox is selected
            await mailService.client.selectMailbox(box);

            // For enough_mail 2.1.6, we need to use the correct method signature
            final imapClient = mailService.client.lowLevelIncomingMailClient as ImapClient;

            // Create a sequence with all UIDs
            final sequence = MessageSequence();
            for (var message in updatedMessages) {
              if (message.uid != null) {
                sequence.add(message.uid!);
              }
            }

            if (sequence.isNotEmpty) {
              if (isSeen) {
                // Mark as read by adding \Seen flag
                await imapClient.uidStore(sequence, [r'\Seen']);
              } else {
                // Mark as unread by removing \Seen flag
                await imapClient.uidStore(sequence, [r'\Seen'], action: StoreAction.remove);
              }
            }
          } catch (e) {
            logger.e("Error updating message flags on server: $e");

            // Fallback to individual updates if batch update fails
            for (var message in updatedMessages) {
              try {
                if (message.uid != null) {
                  // Ensure the correct mailbox is selected
                  await mailService.client.selectMailbox(box);

                  final imapClient = mailService.client.lowLevelIncomingMailClient as ImapClient;
                  final singleSequence = MessageSequence();
                  singleSequence.add(message.uid!);

                  if (isSeen) {
                    await imapClient.uidStore(singleSequence, [r'\Seen']);
                  } else {
                    await imapClient.uidStore(singleSequence, [r'\Seen'], action: StoreAction.remove);
                  }
                }
              } catch (individualError) {
                logger.e("Error updating individual message flag: $individualError");
              }
            }
          }
        }, priority: Priority.normal);
      }
    } catch (e) {
      logger.e("Error marking messages as read/unread: $e");

      // Show error to user
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error updating message status: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      // Release the lock
      _releaseOperationLock(box);

      // Reset operation status
      isOperationInProgress(false);
    }
  }

  /// Delete messages with batch optimization
  Future<void> deleteMails(List<MimeMessage> messages, Mailbox mailbox) async {
    if (messages.isEmpty) return;

    // Set operation status
    isOperationInProgress(true);
    currentOperation.value = 'Deleting messages...';

    // Acquire lock to prevent concurrent operations on the same mailbox
    await _acquireOperationLock(mailbox);

    try {
      // Store deleted messages for potential undo
      if (deletedMessages[mailbox] == null) {
        deletedMessages[mailbox] = [];
      }
      deletedMessages[mailbox]!.addAll(messages);

      // Remove from emails list immediately for real-time UI update
      if (_fetchController.emails[mailbox] != null) {
        final removedUids = messages.map((m) => m.uid).whereType<int>().toList();

        for (var message in messages) {
          _fetchController.emails[mailbox]!.removeWhere((m) => m.uid == message.uid);
        }

        // Notify about changes
        _fetchController.notifyEmailsChanged(
            mailbox,
            UpdateType.remove,
            messages,
            removedUids: removedUids
        );
      }

      // Delete from storage in background
      _backgroundTaskController.queueOperation(() async {
        await _storageController.deleteMessagesBatch(messages, mailbox);
      }, priority: Priority.low);

      // Delete on server if connected
      if (mailService.client.isConnected) {
        _backgroundTaskController.queueOperation(() async {
          try {
            // Ensure the correct mailbox is selected
            await mailService.client.selectMailbox(mailbox);

            // For enough_mail 2.1.6, we need to use the correct method signature
            final imapClient = mailService.client.lowLevelIncomingMailClient as ImapClient;
            final sequence = MessageSequence();

            // Add each message UID to the sequence
            for (var message in messages) {
              if (message.uid != null) {
                sequence.add(message.uid!);
              }
            }

            if (sequence.isNotEmpty) {
              // Mark messages as deleted
              await imapClient.uidStore(sequence, [r'\Deleted']);

              // Expunge to permanently remove
              final result = await imapClient.expunge();

              // Store result for potential undo (though true undo may not be possible after expunge)
              deleteResult = DeleteResult(
                canUndo: false,
                originalMailbox: mailbox,
                targetMailbox: null,
                messages: messages,
              );

              if (deleteResult != null) {
                Get.showSnackbar(
                  GetSnackBar(
                    message: 'messages_deleted'.tr,
                    backgroundColor: Colors.redAccent,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
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
        }, priority: Priority.normal);
      }
    } catch (e) {
      logger.e("Error deleting messages: $e");

      // Show error to user
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error deleting messages: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      // Release the lock
      _releaseOperationLock(mailbox);

      // Reset operation status
      isOperationInProgress(false);
    }
  }

  /// Handle vanished messages from IMAP server
  /// This method is called when the server reports that messages have been removed
  /// Used by mail_service.dart when handling MailVanishedEvent
  Future<void> vanishMails(List<MimeMessage> messages, Mailbox mailbox) async {
    if (messages.isEmpty) return;

    // Acquire lock to prevent concurrent operations on the same mailbox
    await _acquireOperationLock(mailbox);

    try {
      // Remove from emails list immediately for real-time UI update
      if (_fetchController.emails[mailbox] != null) {
        final removedUids = messages.map((m) => m.uid).whereType<int>().toList();

        for (var message in messages) {
          _fetchController.emails[mailbox]!.removeWhere((m) => m.uid == message.uid);
        }

        // Notify about changes
        _fetchController.notifyEmailsChanged(
            mailbox,
            UpdateType.remove,
            messages,
            removedUids: removedUids
        );
      }

      // Delete from storage in background
      _backgroundTaskController.queueOperation(() async {
        await _storageController.deleteMessagesBatch(messages, mailbox);
      }, priority: Priority.low);
    } catch (e) {
      logger.e("Error handling vanished messages: $e");
    } finally {
      // Release the lock
      _releaseOperationLock(mailbox);
    }
  }

  /// Move messages to trash with batch optimization
  Future<void> moveToTrash(List<MimeMessage> messages, Mailbox mailbox) async {
    final trashBox = _mailboxListController.getMailboxByType(isTrash: true);
    if (trashBox != null) {
      await moveMails(messages, mailbox, trashBox);
    } else {
      Get.showSnackbar(
        const GetSnackBar(
          message: 'Trash mailbox not found',
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Move messages to trash with batch optimization
  Future<void> moveMessagesToTrash(List<MimeMessage> messages, Mailbox mailbox) async {
    await moveToTrash(messages, mailbox);
  }

  /// Move messages between mailboxes with batch optimization
  Future<void> moveMails(List<MimeMessage> messages, Mailbox from, Mailbox to) async {
    if (messages.isEmpty) return;

    // Set operation status
    isOperationInProgress(true);
    currentOperation.value = 'Moving messages...';

    // Acquire locks to prevent concurrent operations on both mailboxes
    await _acquireOperationLock(from);
    await _acquireOperationLock(to);

    try {
      // Remove from source mailbox immediately for UI responsiveness
      if (_fetchController.emails[from] != null) {
        final removedUids = messages.map((m) => m.uid).whereType<int>().toList();

        for (var message in messages) {
          _fetchController.emails[from]!.removeWhere((m) => m.uid == message.uid);
        }

        // Notify about changes
        _fetchController.notifyEmailsChanged(
            from,
            UpdateType.remove,
            messages,
            removedUids: removedUids
        );
      }

      // Store move operation for potential undo
      deleteResult = DeleteResult(
        canUndo: true,
        originalMailbox: from,
        targetMailbox: to,
        messages: messages,
      );

      // Move on server if connected
      if (mailService.client.isConnected) {
        _backgroundTaskController.queueOperation(() async {
          try {
            // Ensure the source mailbox is selected
            await mailService.client.selectMailbox(from);

            // For enough_mail 2.1.6, we need to use the correct method signature
            final imapClient = mailService.client.lowLevelIncomingMailClient as ImapClient;
            final sequence = MessageSequence();

            // Add each message UID to the sequence
            for (var message in messages) {
              if (message.uid != null) {
                sequence.add(message.uid!);
              }
            }

            if (sequence.isNotEmpty) {
              // Move messages to target mailbox
              // await imapClient.uidMove(sequence, to.encodedPath);
              // await imapClient.uidMove(sequence: sequence, destinationMailboxPath: to.encodedPath);
              await mailService.client.selectMailbox(to); // Select the target mailbox
              await imapClient.uidMove(sequence);
              // After move, fetch the messages in the target mailbox
              await _fetchController.loadEmailsForBox(to);

              // Show success message
              Get.showSnackbar(
                GetSnackBar(
                  message: 'Messages moved to ${to.name}',
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            logger.e("Error moving messages on server: $e");

            // Show error message
            Get.showSnackbar(
              GetSnackBar(
                message: 'Error moving messages: ${e.toString()}',
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );

            // Try copy and delete as fallback
            try {
              // Ensure the source mailbox is selected
              await mailService.client.selectMailbox(from);

              final imapClient = mailService.client.lowLevelIncomingMailClient as ImapClient;
              final sequence = MessageSequence();

              // Add each message UID to the sequence
              for (var message in messages) {
                if (message.uid != null) {
                  sequence.add(message.uid!);
                }
              }

              if (sequence.isNotEmpty) {
                // Copy messages to target mailbox
                await mailService.client.selectMailbox(to); // Select the target mailbox
                await imapClient.uidCopy(sequence);
                // await imapClient.uidCopy(sequence: sequence, destinationMailboxPath: to.encodedPath);

                // Mark original messages as deleted
                await imapClient.uidStore(sequence, [r'\Deleted']);

                // Expunge to remove
                await imapClient.expunge();

                // After move, fetch the messages in the target mailbox
                await _fetchController.loadEmailsForBox(to);

                // Show success message
                Get.showSnackbar(
                  GetSnackBar(
                    message: 'Messages moved to ${to.name}',
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            } catch (fallbackError) {
              logger.e("Error in fallback move operation: $fallbackError");

              // Show error message
              Get.showSnackbar(
                GetSnackBar(
                  message: 'Error moving messages: ${fallbackError.toString()}',
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          }
        }, priority: Priority.normal);
      }
    } catch (e) {
      logger.e("Error moving messages: $e");

      // Show error to user
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error moving messages: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      // Release the locks
      _releaseOperationLock(from);
      _releaseOperationLock(to);

      // Reset operation status
      isOperationInProgress(false);
    }
  }

  /// Update flag status on messages with batch optimization
  Future<void> updateFlag(List<MimeMessage> messages, Mailbox mailbox) async {
    if (messages.isEmpty) return;

    // Set operation status
    isOperationInProgress(true);
    currentOperation.value = 'Updating flags...';

    // Acquire lock to prevent concurrent operations on the same mailbox
    await _acquireOperationLock(mailbox);

    try {
      final updatedMessages = <MimeMessage>[];

      for (var message in messages) {
        // Create a copy of the message to avoid modifying the original
        // In enough_mail 2.1.6, we need to manually copy the message
        final messageCopy = MimeMessage();
        messageCopy.uid = message.uid;
        messageCopy.sequenceId = message.sequenceId;
        messageCopy.flags = message.flags != null ? List<String>.from(message.flags!) : null;
        messageCopy.isSeen = message.isSeen;
        messageCopy.isAnswered = message.isAnswered;
        messageCopy.isFlagged = !message.isFlagged; // Toggle flag status
        final flags = message.flags ?? [];
        if (flags.contains(r'\Draft')) {
          messageCopy.flags ??= [];
          messageCopy.flags!.add(r'\Draft');
        }
        if (flags.contains(r'\Recent')) {
          messageCopy.flags ??= [];
          messageCopy.flags!.add(r'\Recent');
        }

        updatedMessages.add(messageCopy);
      }

      // Update the emails list immediately for UI responsiveness
      if (_fetchController.emails[mailbox] != null) {
        for (var message in updatedMessages) {
          final index = _fetchController.emails[mailbox]!.indexWhere((m) => m.uid == message.uid);
          if (index >= 0) {
            // Update the flagged status in the original message
            _fetchController.emails[mailbox]![index].isFlagged = message.isFlagged;
          }
        }

        // Notify about changes
        _fetchController.notifyEmailsChanged(mailbox, UpdateType.update, updatedMessages);
      }

      // Update storage in background
      _backgroundTaskController.queueOperation(() async {
        await _storageController.updateMessageFlagsBatch(updatedMessages, mailbox);
      });

      // Update on server if connected
      if (InternetService.instance.connected && mailService.client.isConnected) {
        _backgroundTaskController.queueOperation(() async {
          try {
            // Ensure the correct mailbox is selected
            await mailService.client.selectMailbox(mailbox);

            // For enough_mail 2.1.6, we need to use the correct method signature
            final imapClient = mailService.client.lowLevelIncomingMailClient as ImapClient;

            // Create a sequence with all UIDs
            final sequence = MessageSequence();
            for (var message in updatedMessages) {
              if (message.uid != null) {
                sequence.add(message.uid!);
              }
            }

            if (sequence.isNotEmpty) {
              // Determine action based on first message (assuming all messages have same flag status)
              final isFlagged = updatedMessages.first.isFlagged;

              if (isFlagged) {
                // Add flag
                await imapClient.uidStore(sequence, [r'\Flagged']);
              } else {
                // Remove flag
                await imapClient.uidStore(sequence, [r'\Flagged'], action: StoreAction.remove);
              }
            }
          } catch (e) {
            logger.e("Error updating message flags on server: $e");

            // Fallback to individual updates if batch update fails
            for (var message in updatedMessages) {
              try {
                if (message.uid != null) {
                  // Ensure the correct mailbox is selected
                  await mailService.client.selectMailbox(mailbox);

                  final imapClient = mailService.client.lowLevelIncomingMailClient as ImapClient;
                  final singleSequence = MessageSequence();
                  singleSequence.add(message.uid!);

                  if (message.isFlagged) {
                    await imapClient.uidStore(singleSequence, [r'\Flagged']);
                  } else {
                    await imapClient.uidStore(singleSequence, [r'\Flagged'], action: StoreAction.remove);
                  }
                }
              } catch (individualError) {
                logger.e("Error updating individual message flag: $individualError");
              }
            }
          }
        }, priority: Priority.normal);
      }
    } catch (e) {
      logger.e("Error updating message flags: $e");

      // Show error to user
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error updating message flags: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      // Release the lock
      _releaseOperationLock(mailbox);

      // Reset operation status
      isOperationInProgress(false);
    }
  }

  /// Mark messages as junk with batch optimization
  Future<void> markAsJunk(List<MimeMessage> messages, Mailbox mailbox) async {
    final junkBox = _mailboxListController.getMailboxByType(isJunk: true);
    if (junkBox != null) {
      await moveMails(messages, mailbox, junkBox);
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

  /// Mark messages as not junk with batch optimization
  Future<void> markAsNotJunk(List<MimeMessage> messages, Mailbox mailbox) async {
    final inboxBox = _mailboxListController.getMailboxByType(isInbox: true);
    if (inboxBox != null) {
      await moveMails(messages, mailbox, inboxBox);
    } else {
      Get.showSnackbar(
        const GetSnackBar(
          message: 'Inbox mailbox not found',
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Archive messages with batch optimization
  Future<void> archiveMessages(List<MimeMessage> messages, Mailbox mailbox) async {
    final archiveBox = _mailboxListController.getMailboxByType(isArchive: true);
    if (archiveBox != null) {
      await moveMails(messages, mailbox, archiveBox);
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

  /// Permanently delete messages with batch optimization
  Future<void> permanentlyDeleteMails(List<MimeMessage> messages, Mailbox mailbox) async {
    if (messages.isEmpty) return;

    // Set operation status
    isOperationInProgress(true);
    currentOperation.value = 'Permanently deleting messages...';

    // Acquire lock to prevent concurrent operations on the same mailbox
    await _acquireOperationLock(mailbox);

    try {
      // Remove from emails list immediately for real-time UI update
      if (_fetchController.emails[mailbox] != null) {
        final removedUids = messages.map((m) => m.uid).whereType<int>().toList();

        for (var message in messages) {
          _fetchController.emails[mailbox]!.removeWhere((m) => m.uid == message.uid);
        }

        // Notify about changes
        _fetchController.notifyEmailsChanged(
            mailbox,
            UpdateType.remove,
            messages,
            removedUids: removedUids
        );
      }

      // Delete from storage in background
      _backgroundTaskController.queueOperation(() async {
        await _storageController.deleteMessagesBatch(messages, mailbox);
      }, priority: Priority.low);

      // Delete on server if connected
      if (mailService.client.isConnected) {
        _backgroundTaskController.queueOperation(() async {
          try {
            // Ensure the correct mailbox is selected
            await mailService.client.selectMailbox(mailbox);

            // For enough_mail 2.1.6, we need to use the correct method signature
            final imapClient = mailService.client.lowLevelIncomingMailClient as ImapClient;
            final sequence = MessageSequence();

            // Add each message UID to the sequence
            for (var message in messages) {
              if (message.uid != null) {
                sequence.add(message.uid!);
              }
            }

            if (sequence.isNotEmpty) {
              // Mark messages as deleted
              await imapClient.uidStore(sequence, [r'\Deleted']);
              // await imapClient.uidStore(sequence: sequence, flags: [r'\Deleted']);

              // Expunge to permanently remove
              await imapClient.expunge();

              // Show success message
              Get.showSnackbar(
                GetSnackBar(
                  message: 'messages_permanently_deleted'.tr,
                  backgroundColor: Colors.redAccent,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          } catch (e) {
            logger.e("Error permanently deleting messages on server: $e");

            // Show error message
            Get.showSnackbar(
              GetSnackBar(
                message: 'Error deleting messages: ${e.toString()}',
                backgroundColor: Colors.redAccent,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }, priority: Priority.normal);
      }
    } catch (e) {
      logger.e("Error permanently deleting messages: $e");

      // Show error to user
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error deleting messages: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      // Release the lock
      _releaseOperationLock(mailbox);

      // Reset operation status
      isOperationInProgress(false);
    }
  }

  /// Send a message with improved error handling
  Future<bool> sendMessage(MimeMessage message, {Mailbox? sentMailbox}) async {
    // Set operation status
    isOperationInProgress(true);
    currentOperation.value = 'Sending message...';

    try {
      // Ensure we have a valid connection
      if (!mailService.client.isConnected) {
        await mailService.connect();
      }

      // Send the message
      await mailService.client.sendMessage(message);

      // Save to sent folder if provided
      if (sentMailbox != null) {
        // Acquire lock to prevent concurrent operations on the same mailbox
        await _acquireOperationLock(sentMailbox);

        try {
          // Add to emails list immediately for UI responsiveness
          if (_fetchController.emails[sentMailbox] != null) {
            _fetchController.emails[sentMailbox]!.insert(0, message);

            // Sort messages by date
            _fetchController.emails[sentMailbox]!.sort((a, b) {
              final dateA = a.decodeDate() ?? DateTime.now();
              final dateB = b.decodeDate() ?? DateTime.now();
              return dateB.compareTo(dateA);
            });

            // Notify about changes
            _fetchController.notifyEmailsChanged(sentMailbox, UpdateType.add, [message]);
          }

          // Save to storage in background
          _backgroundTaskController.queueOperation(() async {
            await _storageController.saveMessagesToStorage([message], sentMailbox);
          });

          // Append to sent folder on server
          _backgroundTaskController.queueOperation(() async {
            try {
              // await mailService.client.appendMessage(sentMailbox, message);
              await mailService.appendToSentFolder(sentMailbox, message); // ✅ Valid
            } catch (e) {
              logger.e("Error appending message to sent folder: $e");
            }
          }, priority: Priority.low);
        } finally {
          // Release the lock
          _releaseOperationLock(sentMailbox);
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

      return true;
    } catch (e) {
      logger.e("Error sending message: $e");

      // Show error to user
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error sending message: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );

      return false;
    } finally {
      // Reset operation status
      isOperationInProgress(false);
    }
  }

  /// Mark a single message as seen
  Future<void> markMessageAsSeen(MimeMessage message, Mailbox mailbox) async {
    await markAsReadUnread([message], mailbox, true);
  }

  /// Mark multiple messages as seen
  Future<void> markMessagesAsSeen(List<MimeMessage> messages, Mailbox mailbox) async {
    await markAsReadUnread(messages, mailbox, true);
  }
}

/// Class to store delete operation result for potential undo
class DeleteResult {
  final bool canUndo;
  final Mailbox originalMailbox;
  final Mailbox? targetMailbox;
  final List<MimeMessage> messages;

  DeleteResult({
    required this.canUndo,
    required this.originalMailbox,
    this.targetMailbox,
    required this.messages,
  });
}
