import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/messaging/infrastructure/cache/cache_managers.dart';
import 'package:wahda_bank/features/messaging/infrastructure/datasources/local_store.dart';
import 'package:wahda_bank/features/messaging/infrastructure/dtos/message_row.dart';
import 'package:wahda_bank/features/messaging/infrastructure/dtos/body_row.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';

void main() {
  test(
    'AttachmentCacheManager denies storing > max per item (100MB default)',
    () async {
      final store = InMemoryLocalStore();
      final mgr = AttachmentCacheManager(store: store);
      final big = List<int>.filled(101 * 1024 * 1024, 0); // 101MB

      String? lastName;
      Map<String, Object?>? lastProps;
      Telemetry.onEvent = (name, props) {
        lastName = name;
        lastProps = props;
      };

      final ok = await mgr.canStore('u1', '1', big);
      expect(ok, isFalse);
      expect(lastName, 'cache_miss');
      expect(lastProps?['reason'], 'too_large_to_cache');
    },
  );

  test(
    'BodyCacheManager evicts least-recent while protecting flagged',
    () async {
      final store = InMemoryLocalStore();
      final bodyMgr = BodyCacheManager(
        store: store,
        maxTotalBytes: 1024 * 10, // 10KB cap
        isProtected: (uid) async => uid == 'm1',
      );

      // Seed two messages: one flagged (protected), one not
      final flagged = MessageRow(
        id: 'm1',
        folderId: 'INBOX',
        subject: 's',
        fromName: 'n',
        fromEmail: 'e',
        toEmails: const [],
        dateEpochMs: 1,
        seen: false,
        answered: false,
        flagged: true,
        draft: false,
        deleted: false,
        hasAttachments: false,
        preview: null,
      );
      final normal = MessageRow(
        id: 'm2',
        folderId: 'INBOX',
        subject: 's',
        fromName: 'n',
        fromEmail: 'e',
        toEmails: const [],
        dateEpochMs: 2,
        seen: false,
        answered: false,
        flagged: false,
        draft: false,
        deleted: false,
        hasAttachments: false,
        preview: null,
      );

      await store.upsertHeaders([flagged, normal]);

      // Add large bodies (>cap when combined)
      await store.upsertBody(
        BodyRow(
          messageUid: 'm1',
          mimeType: 'text/plain',
          plainText: 'x' * 9000,
        ),
      );
      await store.upsertBody(
        BodyRow(
          messageUid: 'm2',
          mimeType: 'text/plain',
          plainText: 'y' * 9000,
        ),
      );

      // Touch both; ensure m2 is older (to be evicted)
      bodyMgr.touch('m2');
      await Future<void>.delayed(const Duration(milliseconds: 1));
      bodyMgr.touch('m1');

      await bodyMgr.enforceCaps();

      final b1 = await store.getBody(messageUid: 'm1');
      final b2 = await store.getBody(messageUid: 'm2');
      expect(b1?.plainText, isNotNull); // protected
      // Either evicted (null) or reduced to null content
      expect((b2?.plainText ?? '').isEmpty && (b2?.html ?? '').isEmpty, isTrue);
    },
  );
}
