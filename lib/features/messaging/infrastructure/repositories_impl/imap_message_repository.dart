import 'package:wahda_bank/features/messaging/domain/entities/folder.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/entities/message.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/entities/attachment.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/repositories/message_repository.dart';
import 'package:wahda_bank/features/messaging/domain/entities/search_result.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/value_objects/search_query.dart' as dom;
import 'package:wahda_bank/features/messaging/infrastructure/datasources/local_store.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';
import 'package:wahda_bank/features/messaging/infrastructure/mappers/message_mapper.dart';
import 'package:wahda_bank/features/messaging/infrastructure/dtos/message_row.dart';
import 'package:wahda_bank/features/messaging/infrastructure/dtos/body_row.dart';

class ImapMessageRepository implements MessageRepository {
  final String accountId;
  final ImapGateway gateway;
  final LocalStore store;

  ImapMessageRepository({
    required this.accountId,
    required this.gateway,
    required this.store,
  });

  @override
  Future<List<dom.Message>> fetchInbox({required dom.Folder folder, int limit = 50, int offset = 0}) async {
    // header-first
    final headers = await gateway.fetchHeaders(
      accountId: accountId,
      folderId: folder.id,
      limit: limit,
      offset: offset,
    );
    final rows = headers.map(MessageMapper.fromHeaderDTO).toList();
    await store.upsertHeaders(rows);
    final persisted = await store.getHeaders(folderId: folder.id, limit: limit, offset: offset);
    return persisted.map(MessageMapper.toDomain).toList(growable: false);
  }

  @override
  Future<dom.Message> fetchMessageBody({required dom.Folder folder, required String messageId}) async {
    // Cache-first body fetch
    BodyRow? body = await store.getBody(messageUid: messageId);
    if (body == null) {
      final dto = await gateway.fetchBody(
        accountId: accountId,
        folderId: folder.id,
        messageUid: messageId,
      );
      body = MessageMapper.bodyRowFromDTO(dto);
      await store.upsertBody(body);
    }

    // Merge with existing header to return full domain Message
    final persisted = await store.getHeaders(folderId: folder.id, limit: 10000, offset: 0);
    final row = persisted.firstWhere((r) => r.id == messageId);
    final base = MessageMapper.toDomain(row);
    return base.copyWith(
      plainBody: body.plainText,
      htmlBody: body.html,
    );
  }

  @override
  Future<void> markRead({required dom.Folder folder, required String messageId, required bool read}) async {
    // Update local metadata only for now.
    final rows = await store.getHeaders(folderId: folder.id, limit: 10000, offset: 0);
    final idx = rows.indexWhere((r) => r.id == messageId);
    if (idx >= 0) {
      final updated = MessageRow(
        id: rows[idx].id,
        folderId: rows[idx].folderId,
        subject: rows[idx].subject,
        fromName: rows[idx].fromName,
        fromEmail: rows[idx].fromEmail,
        toEmails: rows[idx].toEmails,
        dateEpochMs: rows[idx].dateEpochMs,
        seen: read,
        answered: rows[idx].answered,
        flagged: rows[idx].flagged,
        draft: rows[idx].draft,
        deleted: rows[idx].deleted,
        hasAttachments: rows[idx].hasAttachments,
        preview: rows[idx].preview,
      );
      await store.upsertHeaders([updated]);
    }
  }

  @override
  Future<List<dom.Attachment>> listAttachments({required dom.Folder folder, required String messageId}) async {
    // Cache-miss → gateway list → store
    var rows = await store.listAttachments(messageUid: messageId);
    if (rows.isEmpty) {
      final dtos = await gateway.listAttachments(
        accountId: accountId,
        folderId: folder.id,
        messageUid: messageId,
      );
      rows = dtos.map(MessageMapper.attachmentRowFromDTO).toList();
      await store.upsertAttachments(rows);
    }
    return rows.map(MessageMapper.attachmentDomainFromRow).toList(growable: false);
  }

  @override
  Future<List<int>> downloadAttachment({required dom.Folder folder, required String messageId, required String partId}) async {
    // Idempotent download: serve from cache if present
    final cached = await store.getAttachmentBlobRef(messageUid: messageId, partId: partId);
    if (cached != null) return cached;

    final bytes = await gateway.downloadAttachment(
      accountId: accountId,
      folderId: folder.id,
      messageUid: messageId,
      partId: partId,
    );
    await store.putAttachmentBlob(messageUid: messageId, partId: partId, bytes: bytes);
    return bytes;
  }
  @override
  Future<List<dom.SearchResult>> search({required String accountId, required dom.SearchQuery q}) async {
    // Local-first search using LocalStore
    final rows = await store.searchMetadata(
      text: q.text,
      from: q.from,
      to: q.to,
      subject: q.subject,
      dateFromEpochMs: q.dateFrom?.millisecondsSinceEpoch,
      dateToEpochMs: q.dateTo?.millisecondsSinceEpoch,
      flags: q.flags,
      limit: q.limit,
    );
    final localResults = rows.map(MessageMapper.searchResultFromRow).toList();

    // Optional remote search disabled by default (internal toggle)
    const bool remoteEnabled = false;
    List<dom.SearchResult> merged = localResults;
    // TODO(P7+): retained for future sync/search path; unused in P6.
    if (remoteEnabled) {
      try {
        // If a specific folder filter exists, search that; else skip for now
        final headers = await gateway.searchHeaders(accountId: accountId, folderId: 'INBOX', q: q);
        final remote = headers.map(MessageMapper.searchResultFromHeader).toList();
        // Dedupe by (folderId,messageId)
        final set = <String>{};
        merged = [
          ...localResults,
          ...remote,
        ].where((r) {
          final key = '${r.folderId}:${r.messageId}';
          final ok = !set.contains(key);
          set.add(key);
          return ok;
        }).toList();
      } catch (e) {
        // Map errors to taxonomy via gateway mapping; ignore remote errors in P6
        final _ = e; // no-op
      }
    }

    // Sort by date DESC and apply limit if necessary
    merged.sort((a, b) => b.date.millisecondsSinceEpoch.compareTo(a.date.millisecondsSinceEpoch));
    if (q.limit != null && merged.length > q.limit!) {
      merged = merged.sublist(0, q.limit!);
    }
    return merged;
  }
}
