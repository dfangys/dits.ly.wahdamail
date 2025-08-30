import '../../domain/repositories/mailbox_repository.dart';

class SubscribeToMailEventsUseCase {
  final IMailboxRepository mailboxRepository;
  const SubscribeToMailEventsUseCase(this.mailboxRepository);

  Stream get stream => mailboxRepository.watchEvents();
}
