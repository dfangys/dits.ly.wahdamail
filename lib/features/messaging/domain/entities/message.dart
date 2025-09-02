/// Domain entity: Message
/// Immutable representation of an email message in the messaging bounded context.
/// No Flutter or third-party SDK imports allowed in domain layer.

class Message {
  final String id; // stable identity (e.g., Message-Id or composite)
  final String folderId;
  final String subject;
  final EmailAddress from;
  final List<EmailAddress> to;
  final List<EmailAddress> cc;
  final List<EmailAddress> bcc;
  final DateTime date;
  final Flags flags;
  final bool hasAttachments;
  final String? previewText;
  final String? plainBody; // optional; populated by fetch body use case
  final String? htmlBody; // optional; populated by fetch body use case
  final String? threadId; // optional thread grouping id

  const Message({
    required this.id,
    required this.folderId,
    required this.subject,
    required this.from,
    required this.to,
    this.cc = const [],
    this.bcc = const [],
    required this.date,
    required this.flags,
    this.hasAttachments = false,
    this.previewText,
    this.plainBody,
    this.htmlBody,
    this.threadId,
  });

  Message copyWith({
    String? id,
    String? folderId,
    String? subject,
    EmailAddress? from,
    List<EmailAddress>? to,
    List<EmailAddress>? cc,
    List<EmailAddress>? bcc,
    DateTime? date,
    Flags? flags,
    bool? hasAttachments,
    String? previewText,
    String? plainBody,
    String? htmlBody,
    String? threadId,
  }) {
    return Message(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      subject: subject ?? this.subject,
      from: from ?? this.from,
      to: to ?? this.to,
      cc: cc ?? this.cc,
      bcc: bcc ?? this.bcc,
      date: date ?? this.date,
      flags: flags ?? this.flags,
      hasAttachments: hasAttachments ?? this.hasAttachments,
      previewText: previewText ?? this.previewText,
      plainBody: plainBody ?? this.plainBody,
      htmlBody: htmlBody ?? this.htmlBody,
      threadId: threadId ?? this.threadId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message &&
        other.id == id &&
        other.folderId == folderId &&
        other.subject == subject &&
        other.from == from &&
        _listEq(other.to, to) &&
        _listEq(other.cc, cc) &&
        _listEq(other.bcc, bcc) &&
        other.date.isAtSameMomentAs(date) &&
        other.flags == flags &&
        other.hasAttachments == hasAttachments &&
        other.previewText == previewText &&
        other.plainBody == plainBody &&
        other.htmlBody == htmlBody &&
        other.threadId == threadId;
  }

  @override
  int get hashCode => Object.hash(
        id,
        folderId,
        subject,
        from,
        _hashList(to),
        _hashList(cc),
        _hashList(bcc),
        date.millisecondsSinceEpoch,
        flags,
        hasAttachments,
        previewText,
        plainBody,
        htmlBody,
        threadId,
      );

  static bool _listEq<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static int _hashList<T>(List<T> list) {
    int hash = 0;
    for (final item in list) {
      hash = 0x1fffffff & (hash + item.hashCode);
      hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
      hash ^= (hash >> 6);
    }
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    hash ^= (hash >> 11);
    hash = 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
    return hash;
  }
}

class EmailAddress {
  final String name; // display name; may be empty
  final String email; // normalized lowercase email

  EmailAddress(this.name, String email)
      : email = email.trim().toLowerCase() {
    if (!_isValidEmail(this.email)) {
      throw ArgumentError('Invalid email address: $email');
    }
  }

  static bool _isValidEmail(String s) {
    // Simple validation to keep domain independent
    final at = s.indexOf('@');
    if (at <= 0 || at == s.length - 1) return false;
    if (s.contains(' ')) return false;
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmailAddress && other.name == name && other.email == email;

  @override
  int get hashCode => Object.hash(name, email);
}

class Flags {
  final bool seen;
  final bool answered;
  final bool flagged;
  final bool draft;
  final bool deleted;

  const Flags({
    this.seen = false,
    this.answered = false,
    this.flagged = false,
    this.draft = false,
    this.deleted = false,
  });

  Flags copyWith({
    bool? seen,
    bool? answered,
    bool? flagged,
    bool? draft,
    bool? deleted,
  }) {
    return Flags(
      seen: seen ?? this.seen,
      answered: answered ?? this.answered,
      flagged: flagged ?? this.flagged,
      draft: draft ?? this.draft,
      deleted: deleted ?? this.deleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Flags &&
          other.seen == seen &&
          other.answered == answered &&
          other.flagged == flagged &&
          other.draft == draft &&
          other.deleted == deleted;

  @override
  int get hashCode => Object.hash(seen, answered, flagged, draft, deleted);
}

