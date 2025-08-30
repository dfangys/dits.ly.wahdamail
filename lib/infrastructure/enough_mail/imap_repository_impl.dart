import '../../domain/entities/email.dart';
import '../../domain/entities/email_event.dart';
import '../../domain/entities/mailbox.dart';
import '../../domain/repositories/mailbox_repository.dart';

/// IMAP repository implementation (EnoughMail-backed)
/// NOTE: Placeholder – actual wiring will be done incrementally.
class ImapRepositoryImpl implements IMailboxRepository {
  ImapRepositoryImpl();

  @override
  Future<List<Mailbox>> listMailboxes() async {
    // TODO: integrate with enough_mail
    return const <Mailbox>[];
  }

  @override
  Future<List<Email>> loadMailbox(MailboxId mailboxId, {int page = 1, int pageSize = 50}) async {
    // TODO: integrate with enough_mail
    return const <Email>[];
  }

  @override
  Future<void> markAsRead(MailboxId mailboxId, MessageId messageId) async {
    // TODO
  }

  @override
  Stream<EmailEvent> watchEvents() {
    // TODO: map MailLoadEvent / MailUpdateEvent / MailVanishedEvent
    return const Stream.empty();
  }
}
