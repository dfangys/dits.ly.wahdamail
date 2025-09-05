import '../entities/draft.dart';

/// Draft repository interface.
abstract class DraftRepository {
  Future<void> saveDraft(Draft draft);
  Future<Draft?> getDraftById(String id);
}
