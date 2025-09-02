import 'package:wahda_bank/features/messaging/domain/entities/draft.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/draft_repository.dart';
import 'package:wahda_bank/features/messaging/infrastructure/datasources/draft_dao.dart';
import 'package:wahda_bank/features/messaging/infrastructure/dtos/draft_row.dart';

class DraftRepositoryImpl implements DraftRepository {
  final DraftDao dao;
  DraftRepositoryImpl(this.dao);

  @override
  Future<Draft?> getDraftById(String id) async {
    final row = await dao.getById(id);
    if (row == null) return null;
    return Draft(
      id: row.id,
      accountId: row.accountId,
      folderId: row.folderId,
      messageId: row.messageId,
      rawBytes: row.rawBytes,
    );
  }

  @override
  Future<void> saveDraft(Draft draft) async {
    final row = DraftRow(
      id: draft.id,
      accountId: draft.accountId,
      folderId: draft.folderId,
      messageId: draft.messageId,
      rawBytes: draft.rawBytes,
    );
    await dao.upsert(row);
  }
}

