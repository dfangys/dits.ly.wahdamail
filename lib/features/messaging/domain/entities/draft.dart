/// Domain entity: Draft (email draft for sending)
class Draft {
  final String id;
  final String accountId;
  final String folderId; // Drafts
  final String messageId;
  final List<int> rawBytes; // rfc822 bytes

  const Draft({
    required this.id,
    required this.accountId,
    required this.folderId,
    required this.messageId,
    required this.rawBytes,
  });
}
