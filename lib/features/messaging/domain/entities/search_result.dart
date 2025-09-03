/// Domain entity: Search result minimal projection
class SearchResult {
  final String messageId;
  final String folderId;
  final DateTime date;
  final double? score; // optional ranking score

  const SearchResult({
    required this.messageId,
    required this.folderId,
    required this.date,
    this.score,
  });
}

