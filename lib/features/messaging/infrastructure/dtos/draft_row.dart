class DraftRow {
  final String id;
  final String accountId;
  final String folderId;
  final String messageId;
  final List<int> rawBytes;

  const DraftRow({
    required this.id,
    required this.accountId,
    required this.folderId,
    required this.messageId,
    required this.rawBytes,
  });
}
