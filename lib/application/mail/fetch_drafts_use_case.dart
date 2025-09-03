import '../../domain/entities/draft.dart';
import '../../domain/repositories/compose_repository.dart';

class FetchDraftsUseCase {
  final IComposeRepository composeRepository;
  const FetchDraftsUseCase(this.composeRepository);

  // Placeholder: drafts would typically be in a DraftRepository; wiring via compose for now.
  Future<List<Draft>> call() async {
    // To be implemented when DraftRepository abstraction is added
    return <Draft>[];
  }
}
