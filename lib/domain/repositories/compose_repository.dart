import '../entities/draft.dart';
import '../entities/email.dart';

abstract class IComposeRepository {
  Future<void> sendEmail(Email email, {MailboxId? sentMailbox});
  Future<Draft> saveDraft(Draft draft);
  Future<void> deleteDraft(int draftId);
}
