import '../value_objects/email_address.dart';

/// Domain repository interface for outbox/queue semantics.
abstract class OutboxRepository {
  /// Enqueue a message for sending; returns a queue id or message id.
  Future<String> enqueue({
    required EmailAddress from,
    required List<EmailAddress> to,
    List<EmailAddress> cc = const [],
    List<EmailAddress> bcc = const [],
    required String subject,
    String? htmlBody,
    String? textBody,
  });

  Future<void> markAsSent(String queueId);
}

