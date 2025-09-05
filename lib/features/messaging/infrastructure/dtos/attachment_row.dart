class AttachmentRow {
  final String messageUid;
  final String partId;
  final String filename;
  final int? sizeBytes;
  final String mimeType;
  final String? contentId;
  final String?
  cachePath; // optional filesystem cache path; for tests we use in-memory blob map

  const AttachmentRow({
    required this.messageUid,
    required this.partId,
    required this.filename,
    required this.mimeType,
    this.sizeBytes,
    this.contentId,
    this.cachePath,
  });

  AttachmentRow copyWith({
    String? messageUid,
    String? partId,
    String? filename,
    int? sizeBytes,
    String? mimeType,
    String? contentId,
    String? cachePath,
  }) => AttachmentRow(
    messageUid: messageUid ?? this.messageUid,
    partId: partId ?? this.partId,
    filename: filename ?? this.filename,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    mimeType: mimeType ?? this.mimeType,
    contentId: contentId ?? this.contentId,
    cachePath: cachePath ?? this.cachePath,
  );
}
