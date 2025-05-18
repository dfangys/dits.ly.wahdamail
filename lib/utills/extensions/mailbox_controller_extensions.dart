import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';

/// Extension methods for MailBoxController class
extension MailBoxControllerExtensions on MailBoxController {
  /// Marks all messages in the current mailbox as read
  Future<void> markAllAsRead(Mailbox mailbox) async {
    try {
      // Get all unread messages in the mailbox
      // Using the actual properties that exist in the user's MailBoxController
      final messages = emails[mailbox]
          ?.where((message) => message.isSeen != true)
          .toList();
      
      if (messages == null || messages.isEmpty) {
        return;
      }
      
      // Create a message sequence for all unread messages
      final sequence = MessageSequence.fromMessages(messages);
      
      // Mark messages as seen on the server
      // Using the actual mailService property that exists in the user's MailBoxController
      if (mailService.client.isConnected) {
        await mailService.client.markSeen(sequence);
      }
      
      // Update local flags
      for (final message in messages) {
        if (message.flags == null) {
          message.flags = [MessageFlags.seen];
        } else if (!message.flags!.contains(MessageFlags.seen)) {
          message.flags!.add(MessageFlags.seen);
        }
      }
      
      // Update storage if available
      if (mailboxStorage[mailbox] != null) {
        await mailboxStorage[mailbox]!.saveMessageEnvelopes(messages);
      }
      
      // Notify UI of changes
      update();
    } catch (e) {
      debugPrint('Error marking all messages as read: $e');
      Get.snackbar(
        'Error',
        'Failed to mark messages as read',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}
