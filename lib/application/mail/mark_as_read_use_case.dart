import '../../domain/entities/email.dart';
import '../../domain/repositories/mailbox_repository.dart';

class MarkAsReadUseCase {
  final IMailboxRepository mailboxRepository;
  const MarkAsReadUseCase(this.mailboxRepository);

  Future<void> call(MailboxId mailboxId, MessageId messageId) async {
    await mailboxRepository.markAsRead(mailboxId, messageId);
  }
}
