/// Domain Event: NewMessageArrived
class NewMessageArrived {
  final String messageId;
  final String folderId;
  final DateTime occurredAt;

  const NewMessageArrived({
    required this.messageId,
    required this.folderId,
    required this.occurredAt,
  });
}
