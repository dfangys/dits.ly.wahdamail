class BodyRow {
  final String messageUid;
  final String mimeType;
  final String? plainText;
  final String? html;
  final int? fetchedAtEpochMs;
  const BodyRow({
    required this.messageUid,
    required this.mimeType,
    this.plainText,
    this.html,
    this.fetchedAtEpochMs,
  });

  BodyRow copyWith({
    String? messageUid,
    String? mimeType,
    String? plainText,
    String? html,
    int? fetchedAtEpochMs,
  }) => BodyRow(
        messageUid: messageUid ?? this.messageUid,
        mimeType: mimeType ?? this.mimeType,
        plainText: plainText ?? this.plainText,
        html: html ?? this.html,
        fetchedAtEpochMs: fetchedAtEpochMs ?? this.fetchedAtEpochMs,
      );
}

