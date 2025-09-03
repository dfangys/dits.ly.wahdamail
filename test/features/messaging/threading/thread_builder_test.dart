import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/messaging/infrastructure/datasources/local_store.dart';
import 'package:wahda_bank/features/messaging/infrastructure/dtos/message_row.dart';
import 'package:wahda_bank/features/messaging/infrastructure/threading/thread_builder.dart';

void main() {
  test('Threading uses RFC headers; subject fallback only when headers missing', () async {
    final store = InMemoryLocalStore();
    await store.upsertHeaders([
      MessageRow(
        id: '1', folderId: 'INBOX', subject: 'Hello', fromName: 'A', fromEmail: 'a@x', toEmails: const [], dateEpochMs: 1,
        seen: false, answered: false, flagged: false, draft: false, deleted: false, hasAttachments: false,
        messageIdHeader: '<m1@x>',
      ),
      MessageRow(
        id: '2', folderId: 'INBOX', subject: 'Re: Hello', fromName: 'B', fromEmail: 'b@x', toEmails: const [], dateEpochMs: 2,
        seen: false, answered: false, flagged: false, draft: false, deleted: false, hasAttachments: false,
        inReplyTo: '<m1@x>',
      ),
      MessageRow(
        id: '3', folderId: 'INBOX', subject: 'Hello', fromName: 'C', fromEmail: 'c@x', toEmails: const [], dateEpochMs: 3,
        seen: false, answered: false, flagged: false, draft: false, deleted: false, hasAttachments: false,
        // no headers -> falls back to subject
      ),
    ]);

    final builder = ThreadBuilder(store);
    final aggs = await builder.build(folderId: 'INBOX');

    // Expect two threads: one for RFC chain (ids 1,2) and one for subject fallback (id 3)
    final threadsByCount = {for (final a in aggs) a.messageUids.length: a};
    expect(threadsByCount[2]!.messageUids, containsAll(['1', '2']));
    expect(threadsByCount[1]!.messageUids, contains('3'));
  });
}

