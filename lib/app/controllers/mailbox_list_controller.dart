import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:wahda_bank/app/controllers/mail_count_controller.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/views/view/models/box_model.dart';
import 'package:wahda_bank/views/box/mailbox_view.dart';

import 'background_task_controller.dart';
import 'email_fetch_controller.dart';
import 'email_ui_state_controller.dart';

/// Extension to add toJson method to Mailbox
extension MailboxExtension on Mailbox {
  Map<String, dynamic> toJson() {
    return {
      'encodedName': encodedName,
      'encodedPath': encodedPath,
      'flags': flags.map((f) => f.toString()).toList(),
      'pathSeparator': pathSeparator,
    };
  }
}

/// Controller responsible for managing the list of mailboxes
class MailboxListController extends GetxController {
  final Logger logger = Logger();
  final getStorage = GetStorage();

  // Mailbox list
  RxList<Mailbox> mailboxes = <Mailbox>[].obs;

  // Currently selected mailbox
  final Rx<Mailbox?> _selectedMailbox = Rx<Mailbox?>(null);
  Mailbox? get selectedMailbox => _selectedMailbox.value;
  set selectedMailbox(Mailbox? value) {
    _selectedMailbox.value = value;
    // Notify other controllers about mailbox selection change
    if (value != null) {
      _notifyMailboxSelectionChanged(value);
    }
  }

  // Default inbox mailbox
  Mailbox mailBoxInbox = Mailbox(
    encodedName: 'inbox',
    encodedPath: 'inbox',
    // Fix: Convert to List<MailboxFlag> for compatibility with enough_mail 2.1.6
    flags: [MailboxFlag.inbox],
    pathSeparator: '',
  );

  // Predefined order for mailboxes
  List<String> predefinedOrder = [
    'inbox',
    'sent',
    'drafts',
    'trash',
    'junk',
    'archive',
  ];

  // Sorted mailboxes based on predefined order
  List<Mailbox> get sortedMailBoxes {
    return mailboxes.toList()
      ..sort((a, b) {
        // Get the index of each item in the predefined order
        int indexA = predefinedOrder.indexOf(a.name.toLowerCase());
        int indexB = predefinedOrder.indexOf(b.name.toLowerCase());
        // Handle cases where the item is not in the predefined order
        if (indexA == -1) indexA = predefinedOrder.length;
        if (indexB == -1) indexB = predefinedOrder.length;
        // Compare based on the indices
        return indexA.compareTo(indexB);
      });
  }

  // Services and controllers
  late MailService mailService;
  late BackgroundTaskController _backgroundTaskController;
  EmailFetchController? _fetchController;
  EmailUiStateController? _uiStateController;

  @override
  void onInit() async {
    super.onInit();

    try {
      mailService = MailService.instance;

      // Get required controllers
      _backgroundTaskController = Get.find<BackgroundTaskController>();

      // Try to find other controllers, but don't fail if not available yet
      if (Get.isRegistered<EmailFetchController>()) {
        _fetchController = Get.find<EmailFetchController>();
      }

      if (Get.isRegistered<EmailUiStateController>()) {
        _uiStateController = Get.find<EmailUiStateController>();
      }

      // Listen for mailbox selection changes
      ever(_selectedMailbox, (mailbox) {
        if (mailbox != null) {
          logger.d("Selected mailbox changed to: ${mailbox.name}");
        }
      });

      await mailService.init();
      await loadMailBoxes();
    } catch (e) {
      logger.e("Error initializing MailboxListController: $e");
    }
  }

  /// Notify other controllers about mailbox selection changes
  void _notifyMailboxSelectionChanged(Mailbox mailbox) {
    try {
      // Update UI state controller if available
      if (_uiStateController != null) {
        _uiStateController!.setSelectedMailbox(mailbox);
      } else if (Get.isRegistered<EmailUiStateController>()) {
        _uiStateController = Get.find<EmailUiStateController>();
        _uiStateController!.setSelectedMailbox(mailbox);
      }

      // Queue operation to ensure mailbox is selected in mail service
      _backgroundTaskController.queueOperation(() async {
        try {
          if (!mailService.client.isConnected) {
            await mailService.connect();
          }
          await mailService.client.selectMailbox(mailbox);
        } catch (e) {
          logger.e("Error selecting mailbox in mail service: $e");
        }
      }, priority: Priority.high);
    } catch (e) {
      logger.e("Error notifying mailbox selection change: $e");
    }
  }

  /// Load mailboxes from storage or server with improved error handling
  Future<void> loadMailBoxes() async {
    try {
      List b = getStorage.read('boxes') ?? [];
      if (b.isEmpty) {
        // No cached mailboxes, fetch from server
        await _backgroundTaskController.executeWithRetry<void>(
              () async {
            await mailService.connect();
            final serverMailboxes = await mailService.client.listMailboxes();
            mailboxes(serverMailboxes);

            // Save mailboxes to storage
            await getStorage.write('boxes', mailboxes.map((box) => box.toJson()).toList());
          },
          maxRetries: 3,
        );
      } else {
        // Use cached mailboxes
        mailboxes(
          b.map((e) => BoxModel.fromJson(e as Map<String, dynamic>)).toList(),
        );

        // Refresh mailboxes in background
        _backgroundTaskController.queueOperation(() async {
          try {
            if (!mailService.client.isConnected) {
              await mailService.connect();
            }

            final serverMailboxes = await mailService.client.listMailboxes();

            // Update mailboxes if there are changes
            if (_mailboxesChanged(serverMailboxes)) {
              mailboxes(serverMailboxes);

              // Save updated mailboxes to storage
              await getStorage.write('boxes', mailboxes.map((box) => box.toJson()).toList());

              // Re-initialize inbox
              initInbox();
            }
          } catch (e) {
            logger.e("Error refreshing mailboxes in background: $e");
          }
        }, priority: Priority.low);
      }

      // Initialize inbox
      initInbox();
    } catch (e) {
      logger.e("Error loading mailboxes: $e");
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error loading mailboxes: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Check if mailboxes have changed
  bool _mailboxesChanged(List<Mailbox> newMailboxes) {
    if (newMailboxes.length != mailboxes.length) {
      return true;
    }

    // Compare paths
    final currentPaths = mailboxes.map((m) => m.encodedPath).toSet();
    final newPaths = newMailboxes.map((m) => m.encodedPath).toSet();

    return !currentPaths.containsAll(newPaths) || !newPaths.containsAll(currentPaths);
  }

  /// Initialize the inbox mailbox
  void initInbox() {
    try {
      mailBoxInbox = mailboxes.firstWhere(
            (element) => element.isInbox,
        orElse: () => mailboxes.isNotEmpty ? mailboxes.first : mailBoxInbox,
      );

      // Set as selected mailbox
      selectedMailbox = mailBoxInbox;

      // Notify EmailFetchController to load emails for inbox
      // Use Future.microtask to ensure controller is available
      Future.microtask(() {
        if (Get.isRegistered<EmailFetchController>()) {
          _fetchController = Get.find<EmailFetchController>();
          _fetchController!.loadEmailsForBox(mailBoxInbox);
        } else {
          // Try again after a short delay
          Future.delayed(Duration(milliseconds: 500), () {
            if (Get.isRegistered<EmailFetchController>()) {
              _fetchController = Get.find<EmailFetchController>();
              _fetchController!.loadEmailsForBox(mailBoxInbox);
            }
          });
        }
      });
    } catch (e) {
      logger.e("Error initializing inbox: $e");
    }
  }

  /// Navigate to a specific mailbox with improved error handling
  void navigateToMailBox(Mailbox box) {
    try {
      // Set as selected mailbox
      selectedMailbox = box;

      // Ensure mail service is connected
      _backgroundTaskController.queueOperation(() async {
        if (!mailService.client.isConnected) {
          await mailService.connect();
        }

        // Ensure the mailbox is selected in mail service
        await mailService.client.selectMailbox(box);
      }, priority: Priority.high);

      // Navigate to the mailbox view with the selected mailbox
      Get.to(() => MailBoxView(mailBox: box));

      // Load emails for this mailbox using EmailFetchController
      if (!Get.isRegistered<EmailFetchController>()) {
        // Wait for controller to be registered
        Future.delayed(const Duration(milliseconds: 500), () {
          if (Get.isRegistered<EmailFetchController>()) {
            _fetchController = Get.find<EmailFetchController>();
            _fetchController!.loadEmailsForBox(box);
          } else {
            // Try one more time after a longer delay
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (Get.isRegistered<EmailFetchController>()) {
                _fetchController = Get.find<EmailFetchController>();
                _fetchController!.loadEmailsForBox(box);
              }
            });
          }
        });
        return;
      }

      _fetchController = Get.find<EmailFetchController>();
      _fetchController!.loadEmailsForBox(box);

      logger.d("Navigated to mailbox: ${box.name}");
    } catch (e) {
      logger.e("Error navigating to mailbox: $e");
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error opening mailbox: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Get a mailbox by type with improved error handling
  Mailbox? getMailboxByType({
    bool isInbox = false,
    bool isSent = false,
    bool isDrafts = false,
    bool isTrash = false,
    bool isJunk = false,
    bool isArchive = false,
  }) {
    try {
      if (isInbox) {
        return mailboxes.firstWhereOrNull((box) => box.isInbox) ??
            mailboxes.firstWhereOrNull((box) => box.name.toLowerCase() == 'inbox');
      } else if (isSent) {
        return mailboxes.firstWhereOrNull((box) => box.isSent) ??
            mailboxes.firstWhereOrNull((box) => box.name.toLowerCase() == 'sent');
      } else if (isDrafts) {
        return mailboxes.firstWhereOrNull((box) => box.isDrafts) ??
            mailboxes.firstWhereOrNull((box) => box.name.toLowerCase() == 'drafts');
      } else if (isTrash) {
        return mailboxes.firstWhereOrNull((box) => box.isTrash) ??
            mailboxes.firstWhereOrNull((box) => box.name.toLowerCase() == 'trash');
      } else if (isJunk) {
        return mailboxes.firstWhereOrNull((box) => box.isJunk) ??
            mailboxes.firstWhereOrNull((box) =>
            box.name.toLowerCase() == 'junk' ||
                box.name.toLowerCase() == 'spam');
      } else if (isArchive) {
        return mailboxes.firstWhereOrNull((box) => box.isArchive) ??
            mailboxes.firstWhereOrNull((box) => box.name.toLowerCase() == 'archive');
      }
    } catch (e) {
      logger.e("Error finding mailbox: $e");
    }
    return null;
  }

  /// Refresh mailboxes from server with improved error handling
  Future<void> refreshMailboxes() async {
    try {
      await _backgroundTaskController.executeWithRetry<void>(
            () async {
          if (!mailService.client.isConnected) {
            await mailService.connect();
          }

          final serverMailboxes = await mailService.client.listMailboxes();
          mailboxes(serverMailboxes);

          // Save updated mailboxes to storage
          await getStorage.write('boxes', mailboxes.map((box) => box.toJson()).toList());

          // Re-initialize inbox
          initInbox();
        },
        maxRetries: 3,
      );

      // Show success message
      Get.showSnackbar(
        const GetSnackBar(
          message: 'Mailboxes refreshed',
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      logger.e("Error refreshing mailboxes: $e");
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error refreshing mailboxes: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Update unread count for a mailbox
  void updateMailboxUnreadCount(Mailbox mailbox) {
    try {
      if (Get.isRegistered<MailCountController>()) {
        final mailCountController = Get.find<MailCountController>();
        final key = mailbox.encodedPath;
        final count = mailbox.messagesUnseen;
        mailCountController.setCount(key, count);
      }
    } catch (e) {
      logger.e("Error updating unread count: $e");
    }
  }

  /// Get mailbox by path
  Mailbox? getMailboxByPath(String path) {
    try {
      return mailboxes.firstWhereOrNull((box) => box.encodedPath == path);
    } catch (e) {
      logger.e("Error finding mailbox by path: $e");
      return null;
    }
  }

  /// Create a new mailbox
  Future<bool> createMailbox(String name) async {
    try {
      await _backgroundTaskController.executeWithRetry<void>(
            () async {
          if (!mailService.client.isConnected) {
            await mailService.connect();
          }

          await mailService.client.createMailbox(name);

          // Refresh mailboxes
          final serverMailboxes = await mailService.client.listMailboxes();
          mailboxes(serverMailboxes);

          // Save updated mailboxes to storage
          await getStorage.write('boxes', mailboxes.map((box) => box.toJson()).toList());
        },
        maxRetries: 3,
      );

      // Show success message
      Get.showSnackbar(
        GetSnackBar(
          message: 'Mailbox "$name" created',
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      return true;
    } catch (e) {
      logger.e("Error creating mailbox: $e");
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error creating mailbox: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }
  }

  /// Delete a mailbox
  Future<bool> deleteMailbox(Mailbox mailbox) async {
    try {
      await _backgroundTaskController.executeWithRetry<void>(
            () async {
          if (!mailService.client.isConnected) {
            await mailService.connect();
          }

          await mailService.client.deleteMailbox(mailbox);

          // Refresh mailboxes
          final serverMailboxes = await mailService.client.listMailboxes();
          mailboxes(serverMailboxes);

          // Save updated mailboxes to storage
          await getStorage.write('boxes', mailboxes.map((box) => box.toJson()).toList());

          // If the deleted mailbox was selected, select inbox
          if (selectedMailbox?.encodedPath == mailbox.encodedPath) {
            initInbox();
          }
        },
        maxRetries: 3,
      );

      // Show success message
      Get.showSnackbar(
        GetSnackBar(
          message: 'Mailbox "${mailbox.name}" deleted',
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      return true;
    } catch (e) {
      logger.e("Error deleting mailbox: $e");
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error deleting mailbox: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return false;
    }
  }

  /// Rename a mailbox
  // Future<bool> renameMailbox(Mailbox mailbox, String newName) async {
  //   try {
  //     await _backgroundTaskController.executeWithRetry<void>(
  //           () async {
  //         if (!mailService.client.isConnected) {
  //           await mailService.connect();
  //         }
  //
  //         // In enough_mail 2.1.6, we need to use the IMAP client directly
  //         final imapClient = mailService.client.lowLevelIncomingMailClient as ImapClient;
  //         await imapClient.renameMailbox(mailbox.encodedPath, newName);
  //
  //         // Refresh mailboxes
  //         final serverMailboxes = await mailService.client.listMailboxes();
  //         mailboxes(serverMailboxes);
  //
  //         // Save updated mailboxes to storage
  //         await getStorage.write('boxes', mailboxes.map((box) => box.toJson()).toList());
  //
  //         // If the renamed mailbox was selected, update selection
  //         if (selectedMailbox?.encodedPath == mailbox.encodedPath) {
  //           final newMailbox = mailboxes.firstWhereOrNull((box) => box.encodedName == newName);
  //           if (newMailbox != null) {
  //             selectedMailbox = newMailbox;
  //           }
  //         }
  //       },
  //       maxRetries: 3,
  //     );
  //
  //     // Show success message
  //     Get.showSnackbar(
  //       GetSnackBar(
  //         message: 'Mailbox renamed to "$newName"',
  //         backgroundColor: Colors.green,
  //         duration: const Duration(seconds: 2),
  //       ),
  //     );
  //
  //     return true;
  //   } catch (e) {
  //     logger.e("Error renaming mailbox: $e");
  //     Get.showSnackbar(
  //       GetSnackBar(
  //         message: 'Error renaming mailbox: ${e.toString()}',
  //         backgroundColor: Colors.red,
  //         duration: const Duration(seconds: 3),
  //       ),
  //     );
  //     return false;
  //   }
  // }
}
