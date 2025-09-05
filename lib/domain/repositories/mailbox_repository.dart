import '../entities/email.dart';
import '../entities/email_event.dart';
import '../entities/mailbox.dart';

abstract class IMailboxRepository {
  Future<List<Mailbox>> listMailboxes();
  Future<List<Email>> loadMailbox(
    MailboxId mailboxId, {
    int page = 1,
    int pageSize = 50,
  });
  Future<void> markAsRead(MailboxId mailboxId, MessageId messageId);
  Stream<EmailEvent> watchEvents();
}
