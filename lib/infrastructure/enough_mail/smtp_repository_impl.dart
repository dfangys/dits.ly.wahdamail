import '../../domain/entities/draft.dart';
import '../../domain/entities/email.dart';
import '../../domain/repositories/compose_repository.dart';

/// SMTP repository implementation (EnoughMail-backed)
/// NOTE: Placeholder – actual wiring will be done incrementally.
class SmtpRepositoryImpl implements IComposeRepository {
  SmtpRepositoryImpl();

  @override
  Future<void> sendEmail(Email email, {MailboxId? sentMailbox}) async {
    // TODO: integrate with enough_mail SMTP
  }

  @override
  Future<Draft> saveDraft(Draft draft) async {
    // TODO: save to SQLite + IMAP drafts
    return draft;
  }

  @override
  Future<void> deleteDraft(int draftId) async {
    // TODO
  }
}
