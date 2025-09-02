import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wahda_bank/features/messaging/domain/entities/outbox_item.dart';
import 'package:wahda_bank/features/messaging/domain/value_objects/retry_policy.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/outbox_repository.dart';
import 'package:wahda_bank/features/messaging/infrastructure/datasources/outbox_dao.dart';
import 'package:wahda_bank/features/messaging/infrastructure/repositories_impl/outbox_repository_impl.dart';

class _InMemoryOutboxDao extends InMemoryOutboxDao {}

void main() {
  group('OutboxRepositoryImpl', () {
    test('enqueue idempotent and nextForSend/mark transitions', () async {
      final dao = _InMemoryOutboxDao();
      final repo = OutboxRepositoryImpl(dao);
      final now = DateTime.now();

      final item = OutboxItem(
        id: 'q1',
        accountId: 'acct',
        folderId: 'Drafts',
        messageId: 'm1',
        createdAt: now,
        updatedAt: now,
      );
      final enq1 = await repo.enqueue(item);
      final enq2 = await repo.enqueue(item);
      expect(enq1.id, enq2.id);

      final next = await repo.nextForSend(DateTime.now());
      expect(next?.id, 'q1');

      await repo.markSending('q1');
      await repo.markFailed(id: 'q1', errorClass: 'TransientNetworkError', retryAt: DateTime.now().add(const Duration(minutes: 1)));
      final failed = await repo.listByStatus(OutboxStatus.failed);
      expect(failed, isNotEmpty);

      await repo.markSent('q1');
      final sent = await repo.listByStatus(OutboxStatus.sent);
      expect(sent, isNotEmpty);
    });
  });
}

