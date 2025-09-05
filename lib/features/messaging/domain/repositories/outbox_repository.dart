import '../entities/outbox_item.dart';

/// Outbox repository interface.
abstract class OutboxRepository {
  Future<OutboxItem> enqueue(OutboxItem item);
  Future<OutboxItem?> nextForSend(DateTime now);
  Future<void> markSending(String id);
  Future<void> markSent(String id);
  Future<void> markFailed({
    required String id,
    required String errorClass,
    required DateTime retryAt,
  });
  Future<List<OutboxItem>> listByStatus(OutboxStatus status);
}
