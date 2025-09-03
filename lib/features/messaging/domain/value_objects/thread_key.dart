/// Value Object: ThreadKey for grouping related messages.
class ThreadKey {
  final String value;
  const ThreadKey._(this.value);

  /// Build from canonical string (already normalized)
  factory ThreadKey.fromString(String s) => ThreadKey._(s);

  /// Deterministic key from RFC headers or subject fallback.
  /// If messageId is present use its lowercase trimmed form.
  /// Else, normalize subject by stripping common prefixes (re:, fwd:, fw:) and whitespace.
  static ThreadKey fromHeaders({String? messageId, String? inReplyTo, List<String>? references, required String subject}) {
    String norm(String? s) => (s ?? '').trim().toLowerCase();
    // Pick a stable anchor across the RFC chain: prefer In-Reply-To, then first References entry, then Message-ID
    final irt = norm(inReplyTo);
    final refs = references ?? const <String>[];
    final firstRef = refs.isNotEmpty ? norm(refs.first) : '';
    final msg = norm(messageId);
    final anchor = irt.isNotEmpty
        ? irt
        : (firstRef.isNotEmpty
            ? firstRef
            : (msg.isNotEmpty ? msg : ''));
    if (anchor.isNotEmpty) return ThreadKey._('id:$anchor');
    final subj = _normalizeSubject(subject);
    return ThreadKey._('subj:${subj.toLowerCase()}');
  }

  static String _normalizeSubject(String s) {
    var t = s.trim();
    // Strip common prefixes repeatedly
    final prefixes = RegExp(r'^(re|fwd|fw)\s*:\s*', caseSensitive: false);
    while (prefixes.hasMatch(t)) {
      t = t.replaceFirst(prefixes, '');
      t = t.trim();
    }
    return t;
  }

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) => other is ThreadKey && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

