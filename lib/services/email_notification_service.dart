import 'dart:async';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/services/notifications_service.dart';

class EmailNotificationService {
  static EmailNotificationService? _instance;
  static EmailNotificationService get instance {
    return _instance ??= EmailNotificationService._();
  }

  EmailNotificationService._();

  // Remove separate client and use the one from MailService
  Timer? _pollingTimer;
  bool _isListening = false;
  final Duration _pollInterval = const Duration(seconds: 30);

  // Initialize without creating a separate connection
  Future<void> initialize() async {
    // No need to read credentials or create connection here
    // We'll use the existing MailService client
  }

  Future<bool> connectAndListen() async {
    if (_isListening) {
      if (kDebugMode) {
        print("ℹ️ Already listening for emails");
      }
      return true;
    }

    // Get the mail service instance
    final mailService = MailService.instance;

    // Check if mail service is connected
    if (!mailService.isClientSet || !mailService.client.isConnected) {
      if (kDebugMode) {
        print("⚠️ Mail service not connected yet, will try again later");
      }
      // Schedule a retry after mail service is connected
      Future.delayed(const Duration(seconds: 5), () {
        connectAndListen();
      });
      return false;
    }

    try {
      if (kDebugMode) {
        print("🔌 Setting up email notifications using existing mail connection");
      }

      // Skip IDLE capability check and just use polling mode
      // This is more compatible with different versions of enough_mail
      if (kDebugMode) {
        print("ℹ️ Using polling mode for notifications (more compatible)");
      }

      // Set up listeners for mail events
      _setupMessageListener(mailService.client);
      _isListening = true;
      return true;
    } catch (e) {
      if (kDebugMode) {
        print("❌ Email notification setup error: $e");
      }
      _isListening = false;
      return false;
    }
  }

  void _setupMessageListener(MailClient mailClient) {
    // Use the client's event bus to listen for new messages
    // These listeners will be in addition to the ones in mail_service.dart
    // but they'll be handling different aspects (notifications vs UI updates)
    mailClient.eventBus.on<MailLoadEvent>().listen(_handleMailEvent);
    mailClient.eventBus.on<MailUpdateEvent>().listen(_handleMailEvent);

    if (kDebugMode) {
      print("⏳ Email notification listeners active");
    }
  }

  void _handleMailEvent(dynamic event) async {
    if (kDebugMode) {
      print("📬 Mail event received for notification: ${event.runtimeType}");
    }

    // Process the message for notification
    if (event is MailLoadEvent || event is MailUpdateEvent) {
      MimeMessage message;
      if (event is MailLoadEvent) {
        message = event.message;
      } else {
        message = (event as MailUpdateEvent).message;
      }

      if (!message.isSeen) {
        _processNewMessage(message);
      }
    }
  }

  void _processNewMessage(MimeMessage message) {
    if (kDebugMode) {
      print('📨 New message received for notification:');
      print('From: ${message.from}');
      print('Subject: ${message.decodeSubject()}');
    }

    // Show notification
    NotificationService.instance.showFlutterNotification(
      message.from?[0].email ?? 'Unknown Sender',
      message.decodeSubject() ?? 'New Mail',
      {'action': 'inbox', 'message': message.decodeSubject() ?? ''},
    );
  }

  void disconnect() {
    _pollingTimer?.cancel();
    _isListening = false;
    if (kDebugMode) {
      print("🔌 Email notification service stopped");
    }
    // We don't disconnect the client here since it's managed by mail_service.dart
  }
}
