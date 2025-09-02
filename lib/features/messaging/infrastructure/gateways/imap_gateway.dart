import 'package:enough_mail/enough_mail.dart' as em;
import 'package:wahda_bank/shared/error/errors.dart';

/// Infra DTO: header-only data fetched from IMAP
class HeaderDTO {
  final String id;
  final String folderId;
  final String subject;
  final String fromName;
  final String fromEmail;
  final List<String> toEmails;
  final int dateEpochMs;
  final bool seen;
  final bool answered;
  final bool flagged;
  final bool draft;
  final bool deleted;
  final bool hasAttachments;
  final String? preview;
  const HeaderDTO({
    required this.id,
    required this.folderId,
    required this.subject,
    required this.fromName,
    required this.fromEmail,
    required this.toEmails,
    required this.dateEpochMs,
    required this.seen,
    required this.answered,
    required this.flagged,
    required this.draft,
    required this.deleted,
    required this.hasAttachments,
    this.preview,
  });
}

abstract class ImapGateway {
  Future<List<HeaderDTO>> fetchHeaders({
    required String accountId,
    required String folderId,
    int limit = 50,
    int offset = 0,
  });
}

/// Simple error mapping for IMAP operations to shared error taxonomy.
AppError mapImapError(Object e) {
  final msg = e.toString().toLowerCase();
  if (msg.contains('authentication') || msg.contains('unauth')) {
    return AuthError(e.toString(), e);
  }
  if (msg.contains('timeout')) {
    return TransientNetworkError(e.toString(), e);
  }
  if (msg.contains('maximum number of connections') || msg.contains('rate')) {
    return RateLimitError(e.toString(), e);
  }
  // Default to transient network for unknown IMAP errors during fetch
  return TransientNetworkError(e.toString(), e);
}

/// Enough Mail-backed implementation (not used in tests). Not wired unless flag is ON.
class EnoughImapGateway implements ImapGateway {
  final em.MailClient client;
  EnoughImapGateway(this.client);

  @override
  Future<List<HeaderDTO>> fetchHeaders({
    required String accountId,
    required String folderId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      // Ensure mailbox selected; keep minimal to avoid side-effects
      if (client.selectedMailbox == null ||
          client.selectedMailbox!.encodedPath != folderId) {
        await client.selectMailbox(em.Mailbox(encodedPath: folderId, encodedName: folderId, pathSeparator: '/', flags: []));
      }
      final res = await client.fetchMessageSequence(
        em.MessageSequence.fromRange(1, limit),
        fetchPreference: em.FetchPreference.envelope,
      );
      return res.map((m) {
        final from = (m.from?.isNotEmpty ?? false) ? m.from!.first : em.MailAddress('', '');
        final tos = (m.to ?? const <em.MailAddress>[]).map((a) => a.email).toList();
        final subject = m.decodeSubject() ?? '';
        return HeaderDTO(
          id: (m.uid?.toString() ?? m.sequenceId?.toString() ?? ''),
          folderId: folderId,
          subject: subject,
          fromName: from.personalName ?? '',
          fromEmail: from.email,
          toEmails: tos,
          dateEpochMs: (m.decodeDate() ?? DateTime.fromMillisecondsSinceEpoch(0)).millisecondsSinceEpoch,
          // Keep flags conservative in P2 adapter impl; exact flags from SDK to be refined later.
          seen: false,
          answered: false,
          flagged: false,
          draft: false,
          deleted: false,
          hasAttachments: false,
          preview: null,
        );
      }).toList(growable: false);
    } catch (e) {
      throw mapImapError(e);
    }
  }
}
