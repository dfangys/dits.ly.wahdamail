/// Value Object: Search query for messages (normalized)
class SearchQuery {
  final String? text; // general fulltext-like (subject/from/to/body when cached)
  final String? from;
  final String? to;
  final String? subject;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final Set<String>? flags; // e.g., {"seen","flagged","draft"}
  final int? limit;

  const SearchQuery._({
    this.text,
    this.from,
    this.to,
    this.subject,
    this.dateFrom,
    this.dateTo,
    this.flags,
    this.limit,
  });

  factory SearchQuery({
    String? text,
    String? from,
    String? to,
    String? subject,
    DateTime? dateFrom,
    DateTime? dateTo,
    Set<String>? flags,
    int? limit,
  }) {
    String? n(String? s) => (s == null) ? null : s.trim().toLowerCase().isEmpty ? null : s.trim().toLowerCase();
    final f = flags == null ? null : flags.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();
    return SearchQuery._(
      text: n(text),
      from: n(from),
      to: n(to),
      subject: n(subject),
      dateFrom: dateFrom,
      dateTo: dateTo,
      flags: (f == null || f.isEmpty) ? null : f,
      limit: limit,
    );
  }
}

