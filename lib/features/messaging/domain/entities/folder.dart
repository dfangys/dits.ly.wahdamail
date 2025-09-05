/// Domain entity: Folder (mailbox)
class Folder {
  final String id; // stable identifier (e.g., encoded path)
  final String name; // display name
  final bool isInbox;
  final bool isSent;
  final bool isDrafts;
  final bool isTrash;
  final bool isSpam;

  const Folder({
    required this.id,
    required this.name,
    this.isInbox = false,
    this.isSent = false,
    this.isDrafts = false,
    this.isTrash = false,
    this.isSpam = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Folder &&
          other.id == id &&
          other.name == name &&
          other.isInbox == isInbox &&
          other.isSent == isSent &&
          other.isDrafts == isDrafts &&
          other.isTrash == isTrash &&
          other.isSpam == isSpam;

  @override
  int get hashCode =>
      Object.hash(id, name, isInbox, isSent, isDrafts, isTrash, isSpam);
}
