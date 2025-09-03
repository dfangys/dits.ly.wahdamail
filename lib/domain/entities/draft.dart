import 'attachment.dart';
import 'email.dart';

class Draft {
  final int? id; // local id
  final String subject;
  final String? bodyHtml;
  final String? bodyText;
  final List<EmailAddress> to;
  final List<EmailAddress> cc;
  final List<EmailAddress> bcc;
  final List<Attachment> attachments;
  final DateTime updatedAt;
  final bool isScheduled;
  final DateTime? scheduledFor;

  const Draft({
    this.id,
    required this.subject,
    this.bodyHtml,
    this.bodyText,
    this.to = const [],
    this.cc = const [],
    this.bcc = const [],
    this.attachments = const [],
    required this.updatedAt,
    this.isScheduled = false,
    this.scheduledFor,
  });
}
