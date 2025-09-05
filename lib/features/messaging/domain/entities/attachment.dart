/// Domain entity: Attachment metadata
class Attachment {
  final String messageId;
  final String partId;
  final String filename;
  final int? sizeBytes;
  final String mimeType;
  final String? contentId;
  const Attachment({
    required this.messageId,
    required this.partId,
    required this.filename,
    required this.mimeType,
    this.sizeBytes,
    this.contentId,
  });
}
