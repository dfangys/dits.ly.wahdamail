import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';

import '../../services/mail_service.dart';

/// Extension for MailService class
extension MailServiceExtensions on MailService {
  /// Safely disconnects from the mail server
  Future<void> disconnect() async {
    try {
      // In the user's MailService class, we need to use the dispose method
      // which already calls client.disconnect()
      dispose();
    } catch (e) {
      debugPrint('Error disconnecting from mail server: $e');
    }
  }
}
