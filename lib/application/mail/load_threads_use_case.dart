import '../../domain/repositories/mailbox_repository.dart';
import '../../domain/entities/email.dart';

class LoadThreadsUseCase {
  final IMailboxRepository mailboxRepository;
  const LoadThreadsUseCase(this.mailboxRepository);

  Future<List<Email>> call(MailboxId mailboxId, {int page = 1, int pageSize = 50}) async {
    return mailboxRepository.loadMailbox(mailboxId, page: page, pageSize: pageSize);
  }
}
