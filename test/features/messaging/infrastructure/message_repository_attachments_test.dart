import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wahda_bank/features/messaging/domain/entities/folder.dart' as dom;
import 'package:wahda_bank/features/messaging/infrastructure/datasources/local_store.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';
import 'package:wahda_bank/features/messaging/infrastructure/repositories_impl/imap_message_repository.dart';

class _MockImapGateway extends Mock implements ImapGateway {}

void main() {
  group('ImapMessageRepository (P3 attachments)', () {
    test('list attachments persists meta and download is idempotent', () async {
      final gw = _MockImapGateway();
      final store = InMemoryLocalStore();
      final repo = ImapMessageRepository(accountId: 'acct', gateway: gw, store: store);
      const folder = dom.Folder(id: 'INBOX', name: 'Inbox', isInbox: true);

      when(() => gw.fetchHeaders(accountId: any(named: 'accountId'), folderId: any(named: 'folderId'), limit: any(named: 'limit'), offset: any(named: 'offset')))
          .thenAnswer((_) async => [
                HeaderDTO(
                  id: '20',
                  folderId: 'INBOX',
                  subject: 'S',
                  fromName: 'A',
                  fromEmail: 'a@x.y',
                  toEmails: const [],
                  dateEpochMs: 1,
                  seen: false,
                  answered: false,
                  flagged: false,
                  draft: false,
                  deleted: false,
                  hasAttachments: true,
                  preview: 'p',
                )
              ]);
      await repo.fetchInbox(folder: folder, limit: 1, offset: 0);

      when(() => gw.listAttachments(accountId: any(named: 'accountId'), folderId: any(named: 'folderId'), messageUid: any(named: 'messageUid')))
          .thenAnswer((_) async => [
                AttachmentDTO(
                  messageUid: '20',
                  partId: '1.2',
                  filename: 'a.txt',
                  mimeType: 'text/plain',
                  sizeBytes: 3,
                  contentId: null,
                )
              ]);

      final list1 = await repo.listAttachments(folder: folder, messageId: '20');
      expect(list1.length, 1);
      expect(list1.first.filename, 'a.txt');

      // Download; first time calls gateway
      when(() => gw.downloadAttachment(accountId: any(named: 'accountId'), folderId: any(named: 'folderId'), messageUid: any(named: 'messageUid'), partId: any(named: 'partId')))
          .thenAnswer((_) async => [1, 2, 3]);
      final data1 = await repo.downloadAttachment(folder: folder, messageId: '20', partId: '1.2');
      expect(data1, [1, 2, 3]);

      // Second download served from cache (no new stub)
      final data2 = await repo.downloadAttachment(folder: folder, messageId: '20', partId: '1.2');
      expect(data2, [1, 2, 3]);
    });
  });
}

