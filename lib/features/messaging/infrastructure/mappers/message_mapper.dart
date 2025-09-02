import 'package:wahda_bank/features/messaging/domain/entities/message.dart' as dom;
import 'package:wahda_bank/features/messaging/infrastructure/dtos/message_row.dart';
import 'package:wahda_bank/features/messaging/infrastructure/dtos/body_row.dart';
import 'package:wahda_bank/features/messaging/infrastructure/dtos/attachment_row.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';
import 'package:wahda_bank/features/messaging/domain/entities/body.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/entities/attachment.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/entities/search_result.dart' as dom;

class MessageMapper {
  static MessageRow fromHeaderDTO(HeaderDTO h) {
    return MessageRow(
      id: h.id,
      folderId: h.folderId,
      subject: h.subject,
      fromName: h.fromName,
      fromEmail: h.fromEmail,
      toEmails: h.toEmails,
      dateEpochMs: h.dateEpochMs,
      seen: h.seen,
      answered: h.answered,
      flagged: h.flagged,
      draft: h.draft,
      deleted: h.deleted,
      hasAttachments: h.hasAttachments,
      preview: h.preview,
    );
  }

  static dom.Message toDomain(MessageRow r) {
    return dom.Message(
      id: r.id,
      folderId: r.folderId,
      subject: r.subject,
      from: dom.EmailAddress(r.fromName, r.fromEmail),
      to: r.toEmails.map((e) => dom.EmailAddress('', e)).toList(),
      date: DateTime.fromMillisecondsSinceEpoch(r.dateEpochMs),
      flags: dom.Flags(
        seen: r.seen,
        answered: r.answered,
        flagged: r.flagged,
        draft: r.draft,
        deleted: r.deleted,
      ),
      hasAttachments: r.hasAttachments,
      previewText: r.preview,
    );
  }

  static BodyRow bodyRowFromDTO(BodyDTO b) => BodyRow(
        messageUid: b.messageUid,
        mimeType: b.mimeType,
        plainText: b.plainText,
        html: b.html,
        fetchedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
      );

  static AttachmentRow attachmentRowFromDTO(AttachmentDTO a) => AttachmentRow(
        messageUid: a.messageUid,
        partId: a.partId,
        filename: a.filename,
        sizeBytes: a.sizeBytes,
        mimeType: a.mimeType,
        contentId: a.contentId,
      );

  static dom.BodyContent bodyDomainFromRow(BodyRow r) => dom.BodyContent(
        mimeType: r.mimeType,
        plainText: r.plainText,
        html: r.html,
        sizeBytesEstimate: null,
      );

  static dom.Attachment attachmentDomainFromRow(AttachmentRow r) => dom.Attachment(
        messageId: r.messageUid,
        partId: r.partId,
        filename: r.filename,
        sizeBytes: r.sizeBytes,
        mimeType: r.mimeType,
        contentId: r.contentId,
      );

  static dom.SearchResult searchResultFromRow(MessageRow r) => dom.SearchResult(
        messageId: r.id,
        folderId: r.folderId,
        date: DateTime.fromMillisecondsSinceEpoch(r.dateEpochMs),
      );

  static dom.SearchResult searchResultFromHeader(HeaderDTO h) => dom.SearchResult(
        messageId: h.id,
        folderId: h.folderId,
        date: DateTime.fromMillisecondsSinceEpoch(h.dateEpochMs),
      );
}
