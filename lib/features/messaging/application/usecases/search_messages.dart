import 'package:wahda_bank/features/messaging/domain/repositories/message_repository.dart';
import 'package:wahda_bank/features/messaging/domain/entities/search_result.dart';
import 'package:wahda_bank/features/messaging/domain/value_objects/search_query.dart';

class SearchMessages {
  final MessageRepository repo;
  const SearchMessages(this.repo);

  Future<List<SearchResult>> call({
    required String accountId,
    required SearchQuery query,
  }) async {
    final q = query; // already normalized in VO
    var results = await repo.search(accountId: accountId, q: q);
    // Enforce limit and sort by date DESC (defensive)
    results.sort(
      (a, b) => b.date.millisecondsSinceEpoch.compareTo(
        a.date.millisecondsSinceEpoch,
      ),
    );
    if (q.limit != null && results.length > q.limit!) {
      results = results.sublist(0, q.limit!);
    }
    return results;
  }
}
