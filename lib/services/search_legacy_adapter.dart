import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/services/mail_service.dart';

/// Legacy search helper: performs IMAP search via MailService client.
/// Keeps presentation free of direct service imports.
class SearchLegacyAdapter {
  static Future<MailSearchResult> searchText(String text) async {
    final client = MailService.instance.client;
    return await client.searchMessages(
      MailSearch(
        text,
        SearchQueryType.allTextHeaders,
        messageType: SearchMessageType.all,
      ),
    );
  }
}

