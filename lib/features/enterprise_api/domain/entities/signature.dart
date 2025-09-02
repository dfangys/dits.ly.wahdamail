class Signature {
  final String id;
  final String contentHtml;
  final bool isDefault;

  const Signature({
    required this.id,
    required this.contentHtml,
    required this.isDefault,
  });

  Signature copyWith({String? contentHtml, bool? isDefault}) => Signature(
        id: id,
        contentHtml: contentHtml ?? this.contentHtml,
        isDefault: isDefault ?? this.isDefault,
      );
}
