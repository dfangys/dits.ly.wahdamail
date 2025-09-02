/// Value Object: Flags
/// Immutable message flags.
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

