class InlineImageRef {
  final String cid;
  final String contentType;
  final int? sizeBytes;
  const InlineImageRef({
    required this.cid,
    required this.contentType,
    this.sizeBytes,
  });
}
