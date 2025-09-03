import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/message_repository.dart' as domain;
import 'package:wahda_bank/features/messaging/domain/entities/folder.dart' as entities;
import 'package:wahda_bank/features/messaging/domain/value_objects/search_query.dart' as q;
import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';
import 'package:wahda_bank/features/sync/infrastructure/sync_service.dart';
import 'package:wahda_bank/features/sync/infrastructure/jitter_backoff.dart';

class _MockMessageRepo extends Mock implements domain.MessageRepository {}

class _FakeGateway implements ImapGateway {
  final StreamController<ImapEvent> ctrl = StreamController.broadcast();

  @override
  Future<List<HeaderDTO>> fetchHeaders({required String accountId, required String folderId, int limit = 50, int offset = 0}) async => [];

  @override
  Future<List<HeaderDTO>> searchHeaders({required String accountId, required String folderId, required q.SearchQuery q}) async => [];

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
    registerFallbackValue(const entities.Folder(id: 'INBOX', name: 'INBOX', isInbox: true));
  });

  test('SyncService triggers header fetch on IDLE events', () async {
    final gw = _FakeGateway();
    final repo = _MockMessageRepo();
    final svc = SyncService(gateway: gw, messages: repo, backoff: JitterBackoff());

    when(() => repo.fetchInbox(folder: any(named: 'folder'), limit: any(named: 'limit'), offset: any(named: 'offset')))
        .thenAnswer((_) async => []);

    await svc.start(accountId: 'acct', folderId: 'INBOX');

    gw.ctrl.add(const ImapEvent(type: ImapEventType.exists, folderId: 'INBOX'));
    await Future<void>.delayed(const Duration(milliseconds: 400));

    verify(() => repo.fetchInbox(folder: const entities.Folder(id: 'INBOX', name: 'INBOX'), limit: 50, offset: 0)).called(1);

    await svc.stop();
  });

  test('SyncService coalesces burst events within debounce window', () async {
    final gw = _FakeGateway();
    final repo = _MockMessageRepo();
    final svc = SyncService(gateway: gw, messages: repo, backoff: JitterBackoff());

    when(() => repo.fetchInbox(folder: any(named: 'folder'), limit: any(named: 'limit'), offset: any(named: 'offset')))
        .thenAnswer((_) async => []);

    await svc.start(accountId: 'acct', folderId: 'INBOX');

    // Burst of events
    gw.ctrl.add(const ImapEvent(type: ImapEventType.exists, folderId: 'INBOX'));
    gw.ctrl.add(const ImapEvent(type: ImapEventType.flagsChanged, folderId: 'INBOX'));
    gw.ctrl.add(const ImapEvent(type: ImapEventType.expunge, folderId: 'INBOX'));

    await Future<void>.delayed(const Duration(milliseconds: 400));
    verify(() => repo.fetchInbox(folder: const entities.Folder(id: 'INBOX', name: 'INBOX'), limit: 50, offset: 0)).called(1);

    await svc.stop();
  });
}

