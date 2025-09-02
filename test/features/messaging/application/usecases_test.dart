import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:wahda_bank/features/messaging/application/usecases/fetch_inbox.dart';
import 'package:wahda_bank/features/messaging/application/usecases/fetch_message_body.dart';
import 'package:wahda_bank/features/messaging/application/usecases/send_email.dart';
import 'package:wahda_bank/features/messaging/application/usecases/mark_read.dart';

import 'package:wahda_bank/features/messaging/domain/entities/folder.dart';
import 'package:wahda_bank/features/messaging/domain/entities/message.dart' as ent;
import 'package:wahda_bank/features/messaging/domain/repositories/folder_repository.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/message_repository.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/outbox_repository.dart';
import 'package:wahda_bank/features/messaging/domain/value_objects/email_address.dart';

class _MockFolderRepo extends Mock implements FolderRepository {}
class _MockMessageRepo extends Mock implements MessageRepository {}
class _MockOutboxRepo extends Mock implements OutboxRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(const Folder(id: 'INBOX', name: 'Inbox', isInbox: true));
    registerFallbackValue(EmailAddress('', 'a@e.com'));
  });

  group('FetchInbox', () {
    test('fetches inbox from folder repo and delegates to message repo', () async {
      final folderRepo = _MockFolderRepo();
      final messageRepo = _MockMessageRepo();
      final uc = FetchInbox(folderRepo, messageRepo);

      const inbox = Folder(id: 'INBOX', name: 'Inbox', isInbox: true);
      when(() => folderRepo.getInbox()).thenAnswer((_) async => inbox);
      when(() => messageRepo.fetchInbox(folder: inbox, limit: any(named: 'limit'), offset: any(named: 'offset')))
          .thenAnswer((_) async => <ent.Message>[]);

      final res = await uc();
      expect(res, isA<List<ent.Message>>());
      verify(() => folderRepo.getInbox()).called(1);
      verify(() => messageRepo.fetchInbox(folder: inbox, limit: 50, offset: 0)).called(1);
    });
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
      when(() => repo.fetchMessageBody(folder: folder, messageId: 'm1'))
          .thenAnswer((_) async => msg);

      final got = await uc(folder: folder, messageId: 'm1');
      expect(got?.plainBody, 'Body');
    });
  });

  group('SendEmail', () {
    test('validates and enqueues via outbox', () async {
      final outbox = _MockOutboxRepo();
      final uc = SendEmail(outbox);
      final from = EmailAddress('Alice', 'alice@example.com');
      final to = [EmailAddress('Bob', 'bob@example.com')];

      when(() => outbox.enqueue(
            from: any(named: 'from'),
            to: any(named: 'to'),
            cc: any(named: 'cc'),
            bcc: any(named: 'bcc'),
            subject: any(named: 'subject'),
            htmlBody: any(named: 'htmlBody'),
            textBody: any(named: 'textBody'),
          )).thenAnswer((_) async => 'qid-1');

      final id = await uc(
        from: from,
        to: to,
        subject: 'Hello',
        textBody: 'Hi',
      );
      expect(id, 'qid-1');

      // validation path
      expect(
        () => uc(from: from, to: const [], subject: 's'),
        throwsArgumentError,
      );
      expect(
        () => uc(from: from, to: to, subject: '   '),
        throwsArgumentError,
      );
    });
  });

  group('MarkRead', () {
    test('delegates to message repo', () async {
      final repo = _MockMessageRepo();
      final uc = MarkRead(repo);
      const folder = Folder(id: 'INBOX', name: 'Inbox', isInbox: true);

      when(() => repo.markRead(folder: folder, messageId: 'm1', read: true))
          .thenAnswer((_) async => {});

      await uc(folder: folder, messageId: 'm1', read: true);
      verify(() => repo.markRead(folder: folder, messageId: 'm1', read: true)).called(1);
    });
  });
}

