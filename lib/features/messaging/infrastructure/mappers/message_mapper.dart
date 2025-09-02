import 'package:wahda_bank/features/messaging/domain/entities/message.dart' as dom;
import 'package:wahda_bank/features/messaging/infrastructure/dtos/message_row.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';

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
}
