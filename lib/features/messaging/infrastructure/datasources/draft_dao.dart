import 'package:wahda_bank/features/messaging/infrastructure/dtos/draft_row.dart';

/// In-memory Draft DAO for P4 tests.
abstract class DraftDao {
  Future<void> upsert(DraftRow row);
  Future<DraftRow?> getById(String id);
}

class InMemoryDraftDao implements DraftDao {
  final Map<String, DraftRow> _byId = {};

  @override
  Future<void> upsert(DraftRow row) async {
    _byId[row.id] = row;
  }

  @override
  Future<DraftRow?> getById(String id) async => _byId[id];
}
