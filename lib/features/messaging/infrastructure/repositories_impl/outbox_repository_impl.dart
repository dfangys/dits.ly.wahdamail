import 'package:wahda_bank/features/messaging/domain/entities/outbox_item.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/outbox_repository.dart';
import 'package:wahda_bank/features/messaging/infrastructure/datasources/outbox_dao.dart';
import 'package:wahda_bank/features/messaging/infrastructure/dtos/outbox_row.dart';

class OutboxRepositoryImpl implements OutboxRepository {
  final OutboxDao dao;
  OutboxRepositoryImpl(this.dao);

  static String _statusToStr(OutboxStatus s) => switch (s) {
        OutboxStatus.queued => 'queued',
        OutboxStatus.sending => 'sending',
        OutboxStatus.sent => 'sent',
        OutboxStatus.failed => 'failed',
      };

  static OutboxStatus _strToStatus(String s) => switch (s) {
        'queued' => OutboxStatus.queued,
        'sending' => OutboxStatus.sending,
        'sent' => OutboxStatus.sent,
        _ => OutboxStatus.failed,
      };

  static OutboxRow _toRow(OutboxItem i) => OutboxRow(
        id: i.id,
        accountId: i.accountId,
        folderId: i.folderId,
        messageId: i.messageId,
        attemptCount: i.attemptCount,
        status: _statusToStr(i.status),
        lastErrorClass: i.lastErrorClass,
        retryAtEpochMs: i.retryAt?.millisecondsSinceEpoch,
        createdAtEpochMs: i.createdAt.millisecondsSinceEpoch,
        updatedAtEpochMs: i.updatedAt.millisecondsSinceEpoch,
      );

  static OutboxItem _toDomain(OutboxRow r) => OutboxItem(
        id: r.id,
        accountId: r.accountId,
        folderId: r.folderId,
        messageId: r.messageId,
        attemptCount: r.attemptCount,
        status: _strToStatus(r.status),
        lastErrorClass: r.lastErrorClass,
        retryAt: r.retryAtEpochMs == null ? null : DateTime.fromMillisecondsSinceEpoch(r.retryAtEpochMs!),
        createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAtEpochMs),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(r.updatedAtEpochMs),
      );

  @override
  Future<OutboxItem> enqueue(OutboxItem item) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final row = _toRow(item.copyWith(createdAt: DateTime.fromMillisecondsSinceEpoch(now), updatedAt: DateTime.fromMillisecondsSinceEpoch(now)));
    final stored = await dao.enqueue(row);
    return _toDomain(stored);
  }

  @override
  Future<List<OutboxItem>> listByStatus(OutboxStatus status) async {
    final rows = await dao.listByStatus(_statusToStr(status));
    return rows.map(_toDomain).toList();
  }

  @override
  Future<void> markFailed({required String id, required String errorClass, required DateTime retryAt}) async {
    final row = await dao.getById(id);
    if (row == null) return;
    final updated = row.copyWith(
      attemptCount: row.attemptCount + 1,
      status: 'failed',
      lastErrorClass: errorClass,
      retryAtEpochMs: retryAt.millisecondsSinceEpoch,
      updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    await dao.update(updated);
  }

  @override
  Future<void> markSending(String id) async {
    final row = await dao.getById(id);
    if (row == null) return;
    final updated = row.copyWith(
      status: 'sending',
      updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    await dao.update(updated);
  }

  @override
  Future<void> markSent(String id) async {
    final row = await dao.getById(id);
    if (row == null) return;
    final updated = row.copyWith(
      status: 'sent',
      updatedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
    );
    await dao.update(updated);
  }

  @override
  Future<OutboxItem?> nextForSend(DateTime now) async {
    final row = await dao.nextForSend(now);
    return row == null ? null : _toDomain(row);
  }
}

