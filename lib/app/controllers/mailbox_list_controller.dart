import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:wahda_bank/app/controllers/mail_count_controller.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/views/view/models/box_model.dart';
import 'package:wahda_bank/views/box/mailbox_view.dart';

import 'email_fetch_controller.dart';

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
  final getStoarage = GetStorage();

  // Mailbox list
  RxList<Mailbox> mailboxes = <Mailbox>[].obs;

  // Default inbox mailbox
  Mailbox mailBoxInbox = Mailbox(
    encodedName: 'inbox',
    encodedPath: 'inbox',
    flags: <MailboxFlag>[], // Explicitly typed as List<MailboxFlag>
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

  // Mail service instance
  late MailService mailService;

  @override
  void onInit() async {
    try {
      mailService = MailService.instance;
      await mailService.init();
      await loadMailBoxes();
      super.onInit();
    } catch (e) {
      logger.e(e);
    }
  }

  /// Load mailboxes from storage or server
  Future<void> loadMailBoxes() async {
    List b = getStoarage.read('boxes') ?? [];
    if (b.isEmpty) {
      await mailService.connect();
      mailboxes(await mailService.client.listMailboxes());

      // Save mailboxes to storage
      await getStoarage.write('boxes', mailboxes.map((box) =>
          box.toJson()
      ).toList());
    } else {
      mailboxes(
        b.map((e) => BoxModel.fromJson(e as Map<String, dynamic>)).toList(),
      );
    }

    // Initialize inbox
    initInbox();
  }

  /// Helper method to create Mailbox from JSON
  Mailbox _boxModelFromJson(Map<String, dynamic> json) {
    List<MailboxFlag> mailboxFlags = [];

    if (json['flags'] != null) {
      for (String flagStr in (json['flags'] as List).cast<String>()) {
        final flag = MailboxFlag.values.firstWhere(
              (f) => f.toString().split('.').last.toLowerCase() == flagStr.toLowerCase(),
          orElse: () => MailboxFlag.values.first, // fallback to first
        );
        mailboxFlags.add(flag);
      }
    }

    return Mailbox(
      encodedName: json['encodedName'] ?? '',
      encodedPath: json['encodedPath'] ?? '',
      flags: mailboxFlags,
      pathSeparator: json['pathSeparator'] ?? '',
    );
  }

  /// Initialize the inbox mailbox
  void initInbox() {
    mailBoxInbox = mailboxes.firstWhere(
          (element) => element.isInbox,
      orElse: () => mailboxes.first,
    );

    // Notify EmailFetchController to load emails for inbox
    if (Get.isRegistered<EmailFetchController>()) {
      Get.find<EmailFetchController>().loadEmailsForBox(mailBoxInbox);
    }
  }

  /// Navigate to a specific mailbox
  void navigateToMailBox(Mailbox box) {
    try {
      // Ensure mail service is connected
      if (!mailService.client.isConnected) {
        mailService.connect();
      }

      // Navigate to the mailbox view with the selected mailbox
      Get.to(() => MailBoxView(mailBox: box));

      // Load emails for this mailbox using EmailFetchController
      if (Get.isRegistered<EmailFetchController>()) {
        Get.find<EmailFetchController>().loadEmailsForBox(box);
      }

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

  /// Get a mailbox by type
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
        return mailboxes.firstWhere((box) => box.isInbox);
      } else if (isSent) {
        return mailboxes.firstWhere((box) => box.isSent);
      } else if (isDrafts) {
        return mailboxes.firstWhere((box) => box.isDrafts);
      } else if (isTrash) {
        return mailboxes.firstWhere((box) => box.isTrash);
      } else if (isJunk) {
        return mailboxes.firstWhere((box) => box.isJunk);
      } else if (isArchive) {
        return mailboxes.firstWhere((box) => box.isArchive);
      }
    } catch (e) {
      logger.e("Error finding mailbox: $e");
    }
    return null;
  }

  /// Refresh mailboxes from server
  Future<void> refreshMailboxes() async {
    try {
      if (!mailService.client.isConnected) {
        await mailService.connect();
      }

      final serverMailboxes = await mailService.client.listMailboxes();
      mailboxes(serverMailboxes);

      // Save updated mailboxes to storage
      await getStoarage.write('boxes', mailboxes.map((box) =>
          box.toJson()
      ).toList());

      // Re-initialize inbox
      initInbox();
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
}
