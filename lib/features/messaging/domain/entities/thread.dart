/// Domain entity: Thread (message conversation)
class Thread {
  final String id;
  final String subject;
  final List<String>
  messageIds; // ordered by date asc or desc (unspecified here)

  const Thread({
    required this.id,
    required this.subject,
    required this.messageIds,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Thread &&
          other.id == id &&
          other.subject == subject &&
          _listEq(other.messageIds, messageIds);

  @override
  int get hashCode => Object.hash(id, subject, _hashList(messageIds));

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
