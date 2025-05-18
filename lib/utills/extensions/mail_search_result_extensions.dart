import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';

/// Extension methods for MailSearchResult class
extension MailSearchResultExtensions on MailSearchResult {
  /// Gets the number of messages found in the search result
  /// This is a compatibility method for enough_mail 2.1.6
  int get messagesFound {
    // In enough_mail 2.1.6, we need to check the messages length directly
    if (messages != null) {
      return messages!.length;
    }
    // Fallback to 0 if no messages
    return 0;
  }
}
