class Attachment {
  final String id; // contentId or fetchId
  final String name;
  final String mimeType;
  final int? sizeBytes;
  final bool isInline;

  const Attachment({
    required this.id,
    required this.name,
    required this.mimeType,
    this.sizeBytes,
    this.isInline = false,
  });
}
