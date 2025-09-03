import '../../domain/entities/email.dart';

class MimeToEmailMapper {
  Email mapBasic({
    required MessageId id,
    required String subject,
    required EmailAddress from,
    required List<EmailAddress> to,
    required DateTime date,
    required bool isSeen,
    required bool isFlagged,
    required bool hasAttachments,
    required MailboxId mailboxId,
    int? sizeBytes,
  }) {
    return Email(
      id: id,
      subject: subject,
      from: from,
      to: to,
      date: date,
      isSeen: isSeen,
      isFlagged: isFlagged,
      hasAttachments: hasAttachments,
      mailboxId: mailboxId,
      sizeBytes: sizeBytes,
    );
  }
}
