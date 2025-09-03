import '../../domain/entities/email.dart';
import '../../domain/repositories/compose_repository.dart';

class SendEmailUseCase {
  final IComposeRepository composeRepository;
  const SendEmailUseCase(this.composeRepository);

  Future<void> call(Email email, {MailboxId? sentMailbox}) async {
    await composeRepository.sendEmail(email, sentMailbox: sentMailbox);
  }
}
