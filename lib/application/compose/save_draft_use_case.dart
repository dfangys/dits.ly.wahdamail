import '../../domain/entities/draft.dart';
import '../../domain/repositories/compose_repository.dart';

class SaveDraftUseCase {
  final IComposeRepository composeRepository;
  const SaveDraftUseCase(this.composeRepository);

  Future<Draft> call(Draft draft) async {
    return composeRepository.saveDraft(draft);
  }
}
