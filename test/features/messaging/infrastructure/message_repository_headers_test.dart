import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wahda_bank/features/messaging/domain/entities/folder.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/entities/message.dart' as dom;
import 'package:wahda_bank/features/messaging/infrastructure/datasources/local_store.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';
import 'package:wahda_bank/features/messaging/infrastructure/repositories_impl/imap_message_repository.dart';

class _MockImapGateway extends Mock implements ImapGateway {}

void main() {
  group('ImapMessageRepository (headers-only)', () {
    test('fetchInbox uses gateway -> store -> returns domain', () async {
      final gw = _MockImapGateway();
      final store = InMemoryLocalStore();
      final repo = ImapMessageRepository(accountId: 'acct', gateway: gw, store: store);
      const folder = dom.Folder(id: 'INBOX', name: 'Inbox', isInbox: true);

      final headers = [
        HeaderDTO(
          id: '1',
          folderId: 'INBOX',
          subject: 'Hello',
          fromName: 'Alice',
          fromEmail: 'alice@example.com',
          toEmails: const ['bob@example.com'],
          dateEpochMs: 1000,
          seen: false,
          answered: false,
          flagged: false,
          draft: false,
          deleted: false,
          hasAttachments: false,
          preview: 'Hi',
        ),
      ];

      when(() => gw.fetchHeaders(accountId: any(named: 'accountId'), folderId: any(named: 'folderId'), limit: any(named: 'limit'), offset: any(named: 'offset')))
          .thenAnswer((_) async => headers);

      final list = await repo.fetchInbox(folder: folder, limit: 50, offset: 0);
      expect(list, isA<List<dom.Message>>());
      expect(list.first.subject, 'Hello');

      // ensure persisted
      final persisted = await store.getHeaders(folderId: 'INBOX', limit: 10, offset: 0);
      expect(persisted.length, 1);
      expect(persisted.first.subject, 'Hello');
    });
  });
}

