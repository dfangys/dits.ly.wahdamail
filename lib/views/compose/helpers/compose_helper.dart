import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/views/compose/compose_view.dart';

// This file fixes the issues with MessageBuilder and enum constants in compose.dart

class ComposeHelper {
  // Fixed method to prepare reply to message
  static MessageBuilder prepareReplyToMessage(MimeMessage message, MailAddress from, {bool replyAll = false}) {
    try {
      // Use the proper method from enough_mail 2.1.6
      return MessageBuilder.prepareReplyToMessage(
        message,
        from,
        replyAll: replyAll,
      );
    } catch (e) {
      // Fallback implementation if the method signature has changed
      final builder = MessageBuilder();

      // Set basic properties
      builder.subject = 'Re: ${message.decodeSubject() ?? ""}';

      // Add recipients
      if (message.from != null && message.from!.isNotEmpty) {
        builder.to = message.from!;
      }

      if (replyAll) {
        if (message.to != null) {
          builder.to = [...builder.to ?? [], ...message.to!];
        }
        if (message.cc != null) {
          builder.cc = message.cc!;
        }
      }

      // Set sender
      builder.from = [from];

      return builder;
    }
  }

  // Fixed method to prepare forward message
  static MessageBuilder prepareForwardMessage(MimeMessage message) {
    try {
      // Use the proper method from enough_mail 2.1.6
      return MessageBuilder.prepareForwardMessage(message);
    } catch (e) {
      // Fallback implementation if the method signature has changed
      final builder = MessageBuilder();

      // Set basic properties
      builder.subject = 'Fwd: ${message.decodeSubject() ?? ""}';

      return builder;
    }
  }

  // Fixed method to prepare from draft
  static MessageBuilder prepareFromDraft(MimeMessage draft) {
    try {
      // Use the proper method from enough_mail 2.1.6
      return MessageBuilder.prepareFromDraft(draft);
    } catch (e) {
      // Fallback implementation if the method signature has changed
      final builder = MessageBuilder();

      // Copy properties from draft
      builder.subject = draft.decodeSubject() ?? "";
      builder.to = draft.to;
      builder.cc = draft.cc;
      builder.bcc = draft.bcc;

      return builder;
    }
  }

  // Helper method to show error dialog with fixed enum constants
  static void showErrorDialog(BuildContext context, String title, String message) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error, // Changed from ERROR to error
      animType: AnimType.bottomSlide, // Changed from BOTTOMSLIDE to bottomSlide
      title: title,
      desc: message,
      btnOkOnPress: () {},
      btnOkColor: Colors.red,
    ).show();
  }

  // Helper method to check if MessageBuilder has content
  static bool hasContent(MessageBuilder builder) {
    // Safe way to check if the builder has content without accessing .parts directly
    try {
      return builder.toString().contains('parts:') ||
          builder.to != null ||
          builder.cc != null ||
          builder.bcc != null ||
          builder.subject != null;
    } catch (e) {
      return false;
    }
  }

  // Helper method to navigate to compose screen
  static void navigateToCompose({Map<String, dynamic>? arguments}) {
    Get.to(() => const ComposeView(), arguments: arguments);
  }
}

// Extension to provide backward compatibility for MessageBuilder
extension MessageBuilderExtension on MessageBuilder {
  bool hasContent() {
    return ComposeHelper.hasContent(this);
  }
}
