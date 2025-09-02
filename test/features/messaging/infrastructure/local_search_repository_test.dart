import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wahda_bank/features/messaging/domain/value_objects/search_query.dart' as dom;
import 'package:wahda_bank/features/messaging/infrastructure/datasources/local_store.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';
import 'package:wahda_bank/features/messaging/infrastructure/repositories_impl/imap_message_repository.dart';
import 'package:wahda_bank/features/messaging/infrastructure/dtos/message_row.dart';
import 'package:wahda_bank/features/messaging/infrastructure/dtos/body_row.dart';

class _MockGateway extends Mock implements ImapGateway {}

void main() {
  group('Local search via repository', () {
    test('filters by subject/from/to/date and includes body when cached; sorts and limits', () async {
      final gw = _MockGateway();
      final store = InMemoryLocalStore();
      final repo = ImapMessageRepository(accountId: 'acct', gateway: gw, store: store);

      // Seed headers
      await store.upsertHeaders([
        MessageRow(
          id: '1', folderId: 'INBOX', subject: 'Hello World', fromName: 'Alice', fromEmail: 'alice@example.com',
          toEmails: const ['bob@example.com'], dateEpochMs: 1000, seen: true, answered: false, flagged: false, draft: false, deleted: false, hasAttachments: false, preview: null,
        ),
        MessageRow(
          id: '2', folderId: 'INBOX', subject: 'Re: Plans', fromName: 'Bob', fromEmail: 'bob@example.com',
          toEmails: const ['alice@example.com'], dateEpochMs: 2000, seen: false, answered: false, flagged: true, draft: false, deleted: false, hasAttachments: false, preview: null,
        ),
      ]);

      // Body cached for id=1 to match text
      await store.upsertBody(BodyRow(messageUid: '1', mimeType: 'text/plain', plainText: 'meet at 5pm'));

      // Subject filter
      var res = await repo.search(accountId: 'acct', q: dom.SearchQuery(subject: 'plans'));
      expect(res.map((e) => e.messageId), contains('2'));

      // From filter
      res = await repo.search(accountId: 'acct', q: dom.SearchQuery(from: 'alice'));
      expect(res.map((e) => e.messageId), contains('1'));

      // To filter
      res = await repo.search(accountId: 'acct', q: dom.SearchQuery(to: 'alice'));
      expect(res.map((e) => e.messageId), contains('2'));

      // Text (body)
      res = await repo.search(accountId: 'acct', q: dom.SearchQuery(text: 'meet'));
      expect(res.map((e) => e.messageId), contains('1'));

      // Flags
      res = await repo.search(accountId: 'acct', q: dom.SearchQuery(flags: {'flagged'}));
      expect(res.map((e) => e.messageId), ['2']);

      // Date range
      res = await repo.search(accountId: 'acct', q: dom.SearchQuery(dateFrom: DateTime.fromMillisecondsSinceEpoch(1500)));
      expect(res.map((e) => e.messageId), ['2']);

      // Sort & limit
      res = await repo.search(accountId: 'acct', q: dom.SearchQuery(limit: 1));
      // Should return newest first: id=2
      expect(res.first.messageId, '2');
      expect(res.length, 1);
    });
  });
}

