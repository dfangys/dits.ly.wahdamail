import '../../domain/repositories/mailbox_repository.dart';
import '../../domain/entities/email.dart';

class SyncInboxUseCase {
  final IMailboxRepository mailboxRepository;
  const SyncInboxUseCase(this.mailboxRepository);

  Future<void> call(MailboxId inboxId) async {
    // In a real impl, we might compare local vs remote and update caches
    await mailboxRepository.loadMailbox(inboxId, page: 1, pageSize: 50);
  }
}
