import '../../domain/entities/draft.dart';
import '../../domain/repositories/compose_repository.dart';

/// SQLite-backed draft repository adaptor
/// NOTE: Placeholder – will wrap SQLiteDraftRepository
class SqliteDraftRepositoryImpl implements IComposeRepository {
  SqliteDraftRepositoryImpl();

  @override
  Future<void> sendEmail(email, {sentMailbox}) async {
    // Not handled here; use SMTP repo in composition
    throw UnimplementedError('Use SMTP repo for sendEmail');
  }

  @override
  Future<Draft> saveDraft(Draft draft) async {
    return draft;
  }

  @override
  Future<void> deleteDraft(int draftId) async {}
}
