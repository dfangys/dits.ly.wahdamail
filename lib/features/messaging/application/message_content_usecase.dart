import 'package:injectable/injectable.dart';
import 'package:wahda_bank/services/mail_service.dart';

/// Messaging content use-case: wraps MailService access for presentation.
@lazySingleton
class MessageContentUseCase {
  MessageContentUseCase();

  dynamic get client => MailService.instance.client;
  String get accountEmail => MailService.instance.account.email;

  Future<void> connect() => MailService.instance.connect();

  Future<void> selectMailbox(dynamic mailbox) async {
    await MailService.instance.client.selectMailbox(mailbox);
  }

  Future<dynamic> fetchMessageContents(dynamic message) async {
    return await MailService.instance.client.fetchMessageContents(message);
  }

  Future<List<dynamic>> fetchMessageSequence(
    dynamic seq, {
    dynamic fetchPreference,
  }) async {
    return await MailService.instance.client.fetchMessageSequence(
      seq,
      fetchPreference: fetchPreference,
    );
  }

  Future<List<dynamic>> listMailboxes() async {
    return await MailService.instance.client.listMailboxes();
  }
}

