/// Domain entity: Outbox item representing a pending/attempted send.
enum OutboxStatus { queued, sending, sent, failed }

class OutboxItem {
  final String id;
  final String accountId;
  final String folderId; // Drafts or Sent logical folder id
  final String messageId; // stable id (uid or composed)
  final int attemptCount;
  final OutboxStatus status;
  final String? lastErrorClass; // AuthError, TransientNetworkError, etc.
  final DateTime? retryAt; // when eligible to retry (failed only)
  final DateTime createdAt;
  final DateTime updatedAt;

  const OutboxItem({
    required this.id,
    required this.accountId,
    required this.folderId,
    required this.messageId,
    this.attemptCount = 0,
    this.status = OutboxStatus.queued,
    this.lastErrorClass,
    this.retryAt,
    required this.createdAt,
    required this.updatedAt,
  });

  OutboxItem copyWith({
    String? id,
    String? accountId,
    String? folderId,
    String? messageId,
    int? attemptCount,
    OutboxStatus? status,
    String? lastErrorClass,
    DateTime? retryAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OutboxItem(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      folderId: folderId ?? this.folderId,
      messageId: messageId ?? this.messageId,
      attemptCount: attemptCount ?? this.attemptCount,
      status: status ?? this.status,
      lastErrorClass: lastErrorClass ?? this.lastErrorClass,
      retryAt: retryAt ?? this.retryAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
