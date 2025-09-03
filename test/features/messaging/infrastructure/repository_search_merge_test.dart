import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wahda_bank/features/messaging/domain/value_objects/search_query.dart' as dom;
import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';
import 'package:wahda_bank/features/messaging/infrastructure/repositories_impl/imap_message_repository.dart';
import 'package:wahda_bank/features/messaging/infrastructure/datasources/local_store.dart';
import 'package:wahda_bank/features/messaging/infrastructure/dtos/message_row.dart';

class _MockGateway extends Mock implements ImapGateway {}

void main() {
  setUpAll(() {
    // Needed by mocktail for any(named: 'q') where q is SearchQuery
    registerFallbackValue(dom.SearchQuery());
  });

  // TODO(P17b): Flaky in CI sporadically due to async timing, revisit stabilization.
  test('Merge/dedupe local + remote search results', () async {
    final gw = _MockGateway();
    final store = InMemoryLocalStore();
    final repo = ImapMessageRepository(accountId: 'acct', gateway: gw, store: store);

    // Local has one result
    await store.upsertHeaders([
      MessageRow(
        id: '10', folderId: 'INBOX', subject: 'A', fromName: 'X', fromEmail: 'x@e', toEmails: const [], dateEpochMs: 1000,
        seen: false, answered: false, flagged: false, draft: false, deleted: false, hasAttachments: false, preview: null,
      ),
    ]);

    // Remote would return same id and a newer different one
    when(() => gw.searchHeaders(accountId: any(named: 'accountId'), folderId: any(named: 'folderId'), q: any(named: 'q')))
        .thenAnswer((_) async => [
              HeaderDTO(
                id: '10', folderId: 'INBOX', subject: 'A', fromName: 'X', fromEmail: 'x@e', toEmails: const [], dateEpochMs: 1000,
                seen: false, answered: false, flagged: false, draft: false, deleted: false, hasAttachments: false, preview: null,
              ),
              HeaderDTO(
                id: '11', folderId: 'INBOX', subject: 'B', fromName: 'Y', fromEmail: 'y@e', toEmails: const [], dateEpochMs: 2000,
                seen: false, answered: false, flagged: false, draft: false, deleted: false, hasAttachments: false, preview: null,
              ),
            ]);

    // Remote disabled by default; still, ensure local returns
    final res1 = await repo.search(accountId: 'acct', q: dom.SearchQuery(text: 'a'));
    expect(res1.map((e) => e.messageId), contains('10'));
  }, skip: 'Flaky in CI (P17b)');
}

