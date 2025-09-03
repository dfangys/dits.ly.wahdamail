class NewMessageArrived {
  final String accountId;
  final String folderId;
  final String threadKey; // domain thread grouping key
  final String messageId;
  final String from;
  final String subject;
  final DateTime date;
  const NewMessageArrived({
    required this.accountId,
    required this.folderId,
    required this.threadKey,
    required this.messageId,
    required this.from,
    required this.subject,
    required this.date,
  });
}

class MessageFlagChanged {
  final String messageId;
  final String folderId;
  final bool seen;
  const MessageFlagChanged({required this.messageId, required this.folderId, required this.seen});
}

class SyncFailed {
  final String accountId;
  final String folderId;
  final String reason;
  const SyncFailed({required this.accountId, required this.folderId, required this.reason});
}
