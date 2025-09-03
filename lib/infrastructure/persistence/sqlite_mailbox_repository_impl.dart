import '../../domain/entities/email.dart';
import '../../domain/entities/email_event.dart';
import '../../domain/entities/mailbox.dart';
import '../../domain/repositories/mailbox_repository.dart';

/// SQLite-backed mailbox repository (cache/read-model)
/// NOTE: Placeholder – will wrap existing SQLiteDatabaseHelper and SQLiteMailboxMimeStorage
class SqliteMailboxRepositoryImpl implements IMailboxRepository {
  SqliteMailboxRepositoryImpl();

  @override
  Future<List<Mailbox>> listMailboxes() async {
    return const <Mailbox>[];
  }

  @override
  Future<List<Email>> loadMailbox(MailboxId mailboxId, {int page = 1, int pageSize = 50}) async {
    return const <Email>[];
  }

  @override
  Future<void> markAsRead(MailboxId mailboxId, MessageId messageId) async {}

  @override
  Stream<EmailEvent> watchEvents() => const Stream.empty();
}
