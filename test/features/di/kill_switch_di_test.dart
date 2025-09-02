import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/messaging/infrastructure/di/messaging_module.dart';
import 'package:wahda_bank/features/messaging/infrastructure/datasources/local_store.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';
import 'package:wahda_bank/features/messaging/domain/value_objects/search_query.dart' as q;

class _FakeGateway implements ImapGateway {
  @override
  Future<List<HeaderDTO>> fetchHeaders({required String accountId, required String folderId, int limit = 50, int offset = 0}) async => [];
  @override
  Future<BodyDTO> fetchBody({required String accountId, required String folderId, required String messageUid}) async =>
      BodyDTO(messageUid: messageUid, mimeType: 'text/plain');
  @override
  Future<List<AttachmentDTO>> listAttachments({required String accountId, required String folderId, required String messageUid}) async => [];
  @override
  Future<List<int>> downloadAttachment({required String accountId, required String folderId, required String messageUid, required String partId}) async => [];
  @override
  Future<List<HeaderDTO>> searchHeaders({required String accountId, required String folderId, required q.SearchQuery q}) async => [];
  @override
  Stream<ImapEvent> idleStream({required String accountId, required String folderId}) => const Stream.empty();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('DI kill switch returns LegacyMessageRepositoryFacade', () async {
    setKillSwitchOverrideForTests(true);
    final repo = wireMessageRepository(gateway: _FakeGateway(), store: InMemoryLocalStore(), accountId: 'acct');
    expect(repo, isA<LegacyMessageRepositoryFacade>());
    // Reset
    setKillSwitchOverrideForTests(null);
  });
}

