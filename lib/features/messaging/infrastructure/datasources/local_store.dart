import 'package:wahda_bank/features/messaging/infrastructure/dtos/message_row.dart';
import 'package:wahda_bank/features/messaging/infrastructure/dtos/body_row.dart';
import 'package:wahda_bank/features/messaging/infrastructure/dtos/attachment_row.dart';

/// Abstraction over local persistence for message metadata
/// Indexes required (for persistent store in future phases):
/// - date DESC
/// - (from, subject)
/// - (flags, date)
/// Bodies/attachments are stored separately from metadata (P3).
/// Simple cache policy (doc-only for now): LRU with global size cap (e.g., 20 MB) for blobs.
abstract class LocalStore {
  // Headers/metadata
  Future<void> upsertHeaders(List<MessageRow> rows);
  Future<List<MessageRow>> getHeaders({required String folderId, int limit = 50, int offset = 0});
  Future<MessageRow?> getHeaderById({required String messageUid});

  // UID tracking per folder (highest seen for windowed sync)
  Future<void> setHighestSeenUid({required String folderId, required int uid});
  Future<int?> getHighestSeenUid({required String folderId});

  // Search metadata (subject/from/to/flags/date) and optionally cached body
  Future<List<MessageRow>> searchMetadata({
    String? text,
    String? from,
    String? to,
    String? subject,
    int? dateFromEpochMs,
    int? dateToEpochMs,
    Set<String>? flags,
    int? limit,
  });

  // Bodies
  Future<void> upsertBody(BodyRow body);
  Future<BodyRow?> getBody({required String messageUid});
  Future<bool> hasBody({required String messageUid});

  // Attachments metadata
  Future<void> upsertAttachments(List<AttachmentRow> rows);
  Future<List<AttachmentRow>> listAttachments({required String messageUid});

  // Attachment blob cache (path or in-memory reference)
  Future<void> putAttachmentBlob({required String messageUid, required String partId, required List<int> bytes});
  Future<List<int>?> getAttachmentBlobRef({required String messageUid, required String partId});
}

/// In-memory implementation for tests and default (P3 does not wire DB yet).
class InMemoryLocalStore implements LocalStore {
  final Map<String, List<MessageRow>> _byFolder = {};
  final Map<String, BodyRow> _bodiesByMessageUid = {};
  final Map<String, List<AttachmentRow>> _attachmentsByMessageUid = {};
  final Map<String, List<int>> _attachmentBlobs = {}; // key: msgUid:partId
  final Map<String, int> _highestUidByFolder = {};

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
  Future<List<MessageRow>> searchMetadata({String? text, String? from, String? to, String? subject, int? dateFromEpochMs, int? dateToEpochMs, Set<String>? flags, int? limit}) async {
    bool containsCI(String haystack, String needle) => haystack.toLowerCase().contains(needle.toLowerCase());
    final all = _byFolder.values.expand((e) => e).toList();
    final filtered = all.where((r) {
      bool ok = true;
      if (from != null) {
        ok = ok && (containsCI(r.fromEmail, from) || containsCI(r.fromName, from));
      }
      if (to != null) {
        ok = ok && r.toEmails.any((e) => containsCI(e, to));
      }
      if (subject != null) {
        ok = ok && containsCI(r.subject, subject);
      }
      if (text != null) {
        final body = _bodiesByMessageUid[r.id];
        final bodyText = body?.plainText ?? '';
        ok = ok && (containsCI(r.subject, text) || containsCI(r.fromEmail, text) || containsCI(r.fromName, text) || r.toEmails.any((e) => containsCI(e, text)) || containsCI(bodyText, text));
      }
      if (dateFromEpochMs != null) {
        ok = ok && r.dateEpochMs >= dateFromEpochMs;
      }
      if (dateToEpochMs != null) {
        ok = ok && r.dateEpochMs <= dateToEpochMs;
      }
      if (flags != null && flags.isNotEmpty) {
        for (final f in flags) {
          switch (f) {
            case 'seen':
              ok = ok && r.seen;
              break;
            case 'answered':
              ok = ok && r.answered;
              break;
            case 'flagged':
              ok = ok && r.flagged;
              break;
            case 'draft':
              ok = ok && r.draft;
              break;
            case 'deleted':
              ok = ok && r.deleted;
              break;
            default:
              ok = ok && true;
          }
        }
      }
      return ok;
    }).toList();
    // Sort by date DESC
    filtered.sort((a, b) => b.dateEpochMs.compareTo(a.dateEpochMs));
    if (limit != null && filtered.length > limit) {
      return filtered.sublist(0, limit);
    }
    return filtered;
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

  @override
  Future<void> upsertBody(BodyRow body) async {
    _bodiesByMessageUid[body.messageUid] = body.copyWith(fetchedAtEpochMs: body.fetchedAtEpochMs ?? DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Future<BodyRow?> getBody({required String messageUid}) async {
    return _bodiesByMessageUid[messageUid];
  }

  @override
  Future<bool> hasBody({required String messageUid}) async {
    return _bodiesByMessageUid.containsKey(messageUid);
  }

  @override
  Future<void> upsertAttachments(List<AttachmentRow> rows) async {
    for (final r in rows) {
      final list = _attachmentsByMessageUid.putIfAbsent(r.messageUid, () => <AttachmentRow>[]);
      final idx = list.indexWhere((x) => x.partId == r.partId);
      if (idx >= 0) {
        list[idx] = r;
      } else {
        list.add(r);
      }
    }
  }

  @override
  Future<List<AttachmentRow>> listAttachments({required String messageUid}) async {
    return List<AttachmentRow>.from(_attachmentsByMessageUid[messageUid] ?? const []);
  }

  String _blobKey(String messageUid, String partId) => '$messageUid:$partId';

  @override
  Future<void> putAttachmentBlob({required String messageUid, required String partId, required List<int> bytes}) async {
    _attachmentBlobs[_blobKey(messageUid, partId)] = List<int>.from(bytes);
  }

  @override
  Future<List<int>?> getAttachmentBlobRef({required String messageUid, required String partId}) async {
    return _attachmentBlobs[_blobKey(messageUid, partId)];
  }
  @override
  Future<MessageRow?> getHeaderById({required String messageUid}) async {
    for (final list in _byFolder.values) {
      final idx = list.indexWhere((r) => r.id == messageUid);
      if (idx >= 0) return list[idx];
    }
    return null;
  }

  @override
  Future<void> setHighestSeenUid({required String folderId, required int uid}) async {
    final prev = _highestUidByFolder[folderId];
    if (prev == null || uid > prev) {
      _highestUidByFolder[folderId] = uid;
    }
  }

  @override
  Future<int?> getHighestSeenUid({required String folderId}) async {
    return _highestUidByFolder[folderId];
  }
}
