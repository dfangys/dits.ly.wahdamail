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
}
