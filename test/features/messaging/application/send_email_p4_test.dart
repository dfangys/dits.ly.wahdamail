import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wahda_bank/features/messaging/application/usecases/send_email.dart';
import 'package:wahda_bank/features/messaging/domain/entities/outbox_item.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/draft_repository.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/outbox_repository.dart';
import 'package:wahda_bank/features/messaging/domain/value_objects/retry_policy.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/smtp_gateway.dart';
import 'package:wahda_bank/features/messaging/domain/entities/draft.dart';

class _MockDrafts extends Mock implements DraftRepository {}

class _MockOutbox extends Mock implements OutboxRepository {}

class _MockSmtp extends Mock implements SmtpGateway {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const Draft(
        id: 'd',
        accountId: 'a',
        folderId: 'Drafts',
        messageId: 'm',
        rawBytes: [],
      ),
    );
    registerFallbackValue(
      OutboxItem(
        id: 'q',
        accountId: 'a',
        folderId: 'Drafts',
        messageId: 'm',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
  });
  group('SendEmail use-case P4', () {
    test('success path', () async {
      final drafts = _MockDrafts();
      final outbox = _MockOutbox();
      final smtp = _MockSmtp();
      final uc = SendEmail(
        drafts: drafts,
        outbox: outbox,
        smtp: smtp,
        retryPolicy: const RetryPolicy(),
      );

      when(() => drafts.saveDraft(any())).thenAnswer((_) async {});
      when(() => outbox.enqueue(any())).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments.first as OutboxItem,
      );
      when(() => outbox.markSending(any())).thenAnswer((_) async {});
      when(
        () => smtp.send(
          accountId: any(named: 'accountId'),
          rawBytes: any(named: 'rawBytes'),
        ),
      ).thenAnswer((_) async => '<id>');
      when(() => outbox.markSent(any())).thenAnswer((_) async {});

      final res = await uc(
        accountId: 'acct',
        folderId: 'Drafts',
        draftId: 'd1',
        messageId: 'm1',
        rawBytes: [0, 1],
      );
      expect(res.status, OutboxStatus.sent);
    });

    test('failure path sets retryAt and increments attempt', () async {
      final drafts = _MockDrafts();
      final outbox = _MockOutbox();
      final smtp = _MockSmtp();
      final uc = SendEmail(
        drafts: drafts,
        outbox: outbox,
        smtp: smtp,
        retryPolicy: const RetryPolicy(),
      );

      when(() => drafts.saveDraft(any())).thenAnswer((_) async {});
      when(() => outbox.enqueue(any())).thenAnswer(
        (invocation) async =>
            invocation.positionalArguments.first as OutboxItem,
      );
      when(() => outbox.markSending(any())).thenAnswer((_) async {});
      when(
        () => smtp.send(
          accountId: any(named: 'accountId'),
          rawBytes: any(named: 'rawBytes'),
        ),
      ).thenThrow(Exception('timeout'));
      when(
        () => outbox.markFailed(
          id: any(named: 'id'),
          errorClass: any(named: 'errorClass'),
          retryAt: any(named: 'retryAt'),
        ),
      ).thenAnswer((_) async {});

      final res = await uc(
        accountId: 'acct',
        folderId: 'Drafts',
        draftId: 'd1',
        messageId: 'm1',
        rawBytes: [0, 1],
      );
      expect(res.status, OutboxStatus.failed);
      expect(res.retryAt, isNotNull);
    });
  });
}
