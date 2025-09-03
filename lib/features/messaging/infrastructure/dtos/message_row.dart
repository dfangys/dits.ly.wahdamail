/// Local store DTO for message metadata (headers only in P2)
class MessageRow {
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

  const MessageRow({
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
