import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/message_repository.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/entities/folder.dart' as dom;
import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';
import 'package:wahda_bank/features/sync/infrastructure/sync_service.dart';
import 'package:wahda_bank/features/sync/infrastructure/jitter_backoff.dart';

class _MockMessageRepo extends Mock implements dom.MessageRepository {}
class _FakeRng extends Fake {}

class _FakeGateway implements ImapGateway {
  final StreamController<ImapEvent> ctrl = StreamController.broadcast();

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
  Stream<ImapEvent> idleStream({required String accountId, required String folderId}) => ctrl.stream;
}

void main() {
  setUpAll(() {
    registerFallbackValue(const dom.Folder(id: 'INBOX', name: 'INBOX', isInbox: true));
  });
  test('SyncService triggers header fetch on IDLE events', () async {
    final gw = _FakeGateway();
    final repo = _MockMessageRepo();
    final svc = SyncService(gateway: gw, messages: repo, backoff: JitterBackoff());

    when(() => repo.fetchInbox(folder: any(named: 'folder'), limit: any(named: 'limit'), offset: any(named: 'offset')))
        .thenAnswer((_) async => []);

    await svc.start(accountId: 'acct', folderId: 'INBOX');

    gw.ctrl.add(const ImapEvent(type: ImapEventType.exists, folderId: 'INBOX'));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    verify(() => repo.fetchInbox(folder: dom.Folder(id: 'INBOX', name: 'INBOX'), limit: 50, offset: 0)).called(1);

    await svc.stop();
  });
}

