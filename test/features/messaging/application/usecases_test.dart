import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wahda_bank/features/messaging/application/usecases/fetch_inbox.dart';
import 'package:wahda_bank/features/messaging/application/usecases/fetch_message_body.dart';
import 'package:wahda_bank/features/messaging/application/usecases/send_email.dart';
import 'package:wahda_bank/features/messaging/domain/entities/outbox_item.dart';
import 'package:wahda_bank/features/messaging/domain/value_objects/retry_policy.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/draft_repository.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/smtp_gateway.dart';
import 'package:wahda_bank/features/messaging/application/usecases/mark_read.dart';
import 'package:wahda_bank/features/messaging/domain/entities/draft.dart';

import 'package:wahda_bank/features/messaging/domain/entities/folder.dart';
import 'package:wahda_bank/features/messaging/domain/entities/message.dart'
    as ent;
import 'package:wahda_bank/features/messaging/domain/repositories/folder_repository.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/message_repository.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/outbox_repository.dart';

class _MockFolderRepo extends Mock implements FolderRepository {}

class _MockMessageRepo extends Mock implements MessageRepository {}

class _MockOutboxRepo extends Mock implements OutboxRepository {}

class _MockDraftRepo extends Mock implements DraftRepository {}

class _MockSmtpGateway extends Mock implements SmtpGateway {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const Folder(id: 'INBOX', name: 'Inbox', isInbox: true),
    );
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

  group('FetchInbox', () {
    test(
      'fetches inbox from folder repo and delegates to message repo',
      () async {
        final folderRepo = _MockFolderRepo();
        final messageRepo = _MockMessageRepo();
        final uc = FetchInbox(folderRepo, messageRepo);

        const inbox = Folder(id: 'INBOX', name: 'Inbox', isInbox: true);
        when(() => folderRepo.getInbox()).thenAnswer((_) async => inbox);
        when(
          () => messageRepo.fetchInbox(
            folder: inbox,
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async => <ent.Message>[]);

        final res = await uc();
        expect(res, isA<List<ent.Message>>());
        verify(() => folderRepo.getInbox()).called(1);
        verify(
          () => messageRepo.fetchInbox(folder: inbox, limit: 50, offset: 0),
        ).called(1);
      },
    );
  });

  group('FetchMessageBody', () {
    test('returns null for empty id; otherwise uses repo', () async {
      final repo = _MockMessageRepo();
      final uc = FetchMessageBody(repo);
      final folder = const Folder(id: 'INBOX', name: 'Inbox', isInbox: true);

      final nullRes = await uc(folder: folder, messageId: '');
      expect(nullRes, isNull);

      final msg = ent.Message(
        id: 'm1',
        folderId: 'INBOX',
        subject: 's',
        from: ent.EmailAddress('', 'a@e.com'),
        to: const [],
        date: DateTime.fromMillisecondsSinceEpoch(0),
        flags: const ent.Flags(),
        plainBody: 'Body',
      );
      when(
        () => repo.fetchMessageBody(folder: folder, messageId: 'm1'),
      ).thenAnswer((_) async => msg);

      final got = await uc(folder: folder, messageId: 'm1');
      expect(got?.plainBody, 'Body');
    });
  });

  group('SendEmail (P4)', () {
    test('success path updates outbox to sent', () async {
      final outbox = _MockOutboxRepo();
      final drafts = _MockDraftRepo();
      final smtp = _MockSmtpGateway();
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
        rawBytes: [1, 2, 3],
      );
      expect(res.status, OutboxStatus.sent);
    });

    test('failure path marks failed and sets retryAt', () async {
      final outbox = _MockOutboxRepo();
      final drafts = _MockDraftRepo();
      final smtp = _MockSmtpGateway();
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
        rawBytes: [1, 2, 3],
      );
      expect(res.status, OutboxStatus.failed);
      expect(res.retryAt, isNotNull);
    });
  });

  group('MarkRead', () {
    test('delegates to message repo', () async {
      final repo = _MockMessageRepo();
      final uc = MarkRead(repo);
      const folder = Folder(id: 'INBOX', name: 'Inbox', isInbox: true);

      when(
        () => repo.markRead(folder: folder, messageId: 'm1', read: true),
      ).thenAnswer((_) async => {});

      await uc(folder: folder, messageId: 'm1', read: true);
      verify(
        () => repo.markRead(folder: folder, messageId: 'm1', read: true),
      ).called(1);
    });
  });
}
