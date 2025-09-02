/// Domain value object for message body content.
class BodyContent {
  final String mimeType;
  final String? plainText;
  final String? html;
  final int? sizeBytesEstimate;
  const BodyContent({
    required this.mimeType,
    this.plainText,
    this.html,
    this.sizeBytesEstimate,
  });
}

