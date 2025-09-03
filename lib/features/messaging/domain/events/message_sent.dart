/// Domain Event: MessageSent
class MessageSent {
  final String messageId;
  final DateTime occurredAt;

  const MessageSent({
    required this.messageId,
    required this.occurredAt,
  });
}

