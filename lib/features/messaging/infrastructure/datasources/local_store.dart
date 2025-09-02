import 'package:wahda_bank/features/messaging/infrastructure/dtos/message_row.dart';

/// Abstraction over local persistence for message metadata
/// Indexes required (for persistent store in future phases):
/// - date DESC
/// - (from, subject)
/// - (flags, date)
/// Bodies/attachments are stored separately from metadata (P3).
abstract class LocalStore {
  Future<void> upsertHeaders(List<MessageRow> rows);
  Future<List<MessageRow>> getHeaders({required String folderId, int limit = 50, int offset = 0});
}

/// In-memory implementation for tests and default (P2 does not wire DB yet).
class InMemoryLocalStore implements LocalStore {
  final Map<String, List<MessageRow>> _byFolder = {};

  @override
  Future<List<MessageRow>> getHeaders({required String folderId, int limit = 50, int offset = 0}) async {
    final list = List<MessageRow>.from(_byFolder[folderId] ?? const []);
    // Sort by date DESC
    list.sort((a, b) => b.dateEpochMs.compareTo(a.dateEpochMs));
    final start = offset.clamp(0, list.length);
    final end = (start + limit).clamp(0, list.length);
    return list.sublist(start, end);
  }

  @override
  Future<void> upsertHeaders(List<MessageRow> rows) async {
    for (final r in rows) {
      final list = _byFolder.putIfAbsent(r.folderId, () => <MessageRow>[]);
      final idx = list.indexWhere((x) => x.id == r.id);
      if (idx >= 0) {
        list[idx] = r;
      } else {
        list.add(r);
      }
    }
  }
}
