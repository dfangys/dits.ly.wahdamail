import 'package:wahda_bank/features/messaging/infrastructure/dtos/outbox_row.dart';

/// In-memory Outbox DAO for P4 tests.
abstract class OutboxDao {
  Future<OutboxRow> enqueue(OutboxRow row);
  Future<OutboxRow?> getById(String id);
  Future<OutboxRow?> getByMessageId(String messageId);
  Future<OutboxRow?> nextForSend(DateTime now);
  Future<void> update(OutboxRow row);
  Future<List<OutboxRow>> listByStatus(String status);
}

class InMemoryOutboxDao implements OutboxDao {
  final Map<String, OutboxRow> _byId = {};
  final Map<String, String> _idByMessageId = {};

  @override
  Future<OutboxRow> enqueue(OutboxRow row) async {
    final existingId = _idByMessageId[row.messageId];
    if (existingId != null) {
      return _byId[existingId]!;
    }
    _byId[row.id] = row;
    _idByMessageId[row.messageId] = row.id;
    return row;
  }

  @override
  Future<OutboxRow?> getById(String id) async => _byId[id];

  @override
  Future<OutboxRow?> getByMessageId(String messageId) async {
    final id = _idByMessageId[messageId];
    return id == null ? null : _byId[id];
  }

  @override
  Future<OutboxRow?> nextForSend(DateTime now) async {
    final values =
        _byId.values.toList()
          ..sort((a, b) => a.createdAtEpochMs.compareTo(b.createdAtEpochMs));
    for (final r in values) {
      final eligible =
          r.status == 'queued' ||
          (r.status == 'failed' &&
              (r.retryAtEpochMs ?? 0) <= now.millisecondsSinceEpoch);
      if (eligible) return r;
    }
    return null;
  }

  @override
  Future<void> update(OutboxRow row) async {
    if (_byId.containsKey(row.id)) {
      _byId[row.id] = row;
    }
  }

  @override
  Future<List<OutboxRow>> listByStatus(String status) async {
    return _byId.values.where((r) => r.status == status).toList();
  }
}
