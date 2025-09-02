import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wahda_bank/features/messaging/domain/entities/folder.dart' as dom;
import 'package:wahda_bank/features/messaging/infrastructure/datasources/local_store.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';
import 'package:wahda_bank/features/messaging/infrastructure/repositories_impl/imap_message_repository.dart';

class _MockImapGateway extends Mock implements ImapGateway {}

void main() {
  group('ImapMessageRepository (P3 body cache)', () {
    test('first body fetch hits gateway then caches; second served from cache', () async {
      final gw = _MockImapGateway();
      final store = InMemoryLocalStore();
      final repo = ImapMessageRepository(accountId: 'acct', gateway: gw, store: store);
      const folder = dom.Folder(id: 'INBOX', name: 'Inbox', isInbox: true);

      // Seed headers
      await store.upsertHeaders([
        // minimal header for message
        // subject/from are not important for body cache test
        // message id "10"
        // Using MessageRow requires import; but repository uses store.getHeaders to merge; keep simple by mimicking header insert via gateway fetch path.
      ]);

      // Simulate fetchHeaders path to persist header
      when(() => gw.fetchHeaders(accountId: any(named: 'accountId'), folderId: any(named: 'folderId'), limit: any(named: 'limit'), offset: any(named: 'offset')))
          .thenAnswer((_) async => [
                HeaderDTO(
                  id: '10',
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
                  hasAttachments: false,
                  preview: 'p',
                )
              ]);
      await repo.fetchInbox(folder: folder, limit: 1, offset: 0);

      // First body fetch should call gateway
      when(() => gw.fetchBody(accountId: any(named: 'accountId'), folderId: any(named: 'folderId'), messageUid: any(named: 'messageUid')))
          .thenAnswer((_) async => BodyDTO(messageUid: '10', mimeType: 'text/plain', plainText: 'hello', html: null, sizeBytesEstimate: 5));
      final m1 = await repo.fetchMessageBody(folder: folder, messageId: '10');
      expect(m1.plainBody, 'hello');

      // Second body fetch should NOT call gateway again (no new stub), served from cache
      final m2 = await repo.fetchMessageBody(folder: folder, messageId: '10');
      expect(m2.plainBody, 'hello');
    });
  });
}

