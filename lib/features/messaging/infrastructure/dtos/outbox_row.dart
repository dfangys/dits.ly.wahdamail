class OutboxRow {
  final String id;
  final String accountId;
  final String folderId;
  final String messageId;
  final int attemptCount;
  final String status; // queued|sending|sent|failed
  final String? lastErrorClass;
  final int? retryAtEpochMs;
  final int createdAtEpochMs;
  final int updatedAtEpochMs;

  const OutboxRow({
    required this.id,
    required this.accountId,
    required this.folderId,
    required this.messageId,
    this.attemptCount = 0,
    this.status = 'queued',
    this.lastErrorClass,
    this.retryAtEpochMs,
    required this.createdAtEpochMs,
    required this.updatedAtEpochMs,
  });

  OutboxRow copyWith({
    String? id,
    String? accountId,
    String? folderId,
    String? messageId,
    int? attemptCount,
    String? status,
    String? lastErrorClass,
    int? retryAtEpochMs,
    int? createdAtEpochMs,
    int? updatedAtEpochMs,
  }) => OutboxRow(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    folderId: folderId ?? this.folderId,
    messageId: messageId ?? this.messageId,
    attemptCount: attemptCount ?? this.attemptCount,
    status: status ?? this.status,
    lastErrorClass: lastErrorClass ?? this.lastErrorClass,
    retryAtEpochMs: retryAtEpochMs ?? this.retryAtEpochMs,
    createdAtEpochMs: createdAtEpochMs ?? this.createdAtEpochMs,
    updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
  );
}
