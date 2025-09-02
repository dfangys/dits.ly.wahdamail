import '../../domain/value_objects/email_address.dart';
import '../../domain/repositories/outbox_repository.dart';

/// Use case: SendEmail (enqueue only at this stage)
class SendEmail {
  final OutboxRepository outbox;

  const SendEmail(this.outbox);

  Future<String> call({
    required EmailAddress from,
    required List<EmailAddress> to,
    List<EmailAddress> cc = const [],
    List<EmailAddress> bcc = const [],
    required String subject,
    String? htmlBody,
    String? textBody,
  }) async {
    if (to.isEmpty) {
      throw ArgumentError('At least one recipient is required');
    }
    if (subject.trim().isEmpty) {
      throw ArgumentError('Subject is required');
    }
    return outbox.enqueue(
      from: from,
      to: to,
      cc: cc,
      bcc: bcc,
      subject: subject,
      htmlBody: htmlBody,
      textBody: textBody,
    );
  }
}

