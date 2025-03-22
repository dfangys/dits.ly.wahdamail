import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';

class EmailNotificationService {
  late ImapClient _client;
  final String _host =
      'wbmail.wahdabank.com.ly'; // Replace with your IMAP server
  final int _port = 43245; // IMAP SSL port
  final String _username = kDebugMode ? "abdullah.salemnaseeb" : "";
  final String _password = kDebugMode ? "Aa102030.@" : "";

  Future<void> connectAndListen({bool useIdle = true}) async {
    _client = ImapClient(isLogEnabled: true);

    try {
      if (kDebugMode) {
        print("🔌 Connecting to IMAP server...");
      }
      await _client.connectToServer(_host, _port, isSecure: true);
      await _client.login(_username, _password);
      if (kDebugMode) {
        print("✅ IMAP Logged in successfully");
      }

      // Select the inbox folder
      await _client.selectInbox();
      if (kDebugMode) {
        print("📩 IMAP Inbox selected");
      }

      if (useIdle) {
        if (kDebugMode) {
          print("🔄 Listening for new emails (IMAP IDLE mode)...");
        }
        _client.enable(['IDLE']);
        _client.idleStart();

        // _client.idle((message) {
        //   if (kDebugMode) {
        //     print("📬 IMAP New email received: $message");
        //   }
        // });
      }
    } catch (e) {
      if (kDebugMode) {
        print("❌ IMAP Connection Error: $e");
      }
    }
  }

  void disconnect() {
    _client.logout();
    if (kDebugMode) {
      print("🔌 Disconnected from IMAP server");
    }
  }
}
