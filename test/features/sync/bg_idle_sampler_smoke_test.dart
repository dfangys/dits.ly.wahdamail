import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/messaging/domain/entities/folder.dart';
import 'package:wahda_bank/features/messaging/domain/entities/message.dart';
import 'package:wahda_bank/features/messaging/domain/entities/attachment.dart';
import 'package:wahda_bank/features/messaging/domain/entities/search_result.dart';
import 'package:wahda_bank/features/messaging/domain/value_objects/search_query.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/message_repository.dart' as repo;
import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';
import 'package:wahda_bank/features/sync/infrastructure/bg_fetch_ios.dart';
import 'package:wahda_bank/features/sync/application/event_bus.dart';
import 'package:wahda_bank/features/sync/infrastructure/circuit_breaker.dart';
import 'package:wahda_bank/features/sync/infrastructure/connectivity_monitor.dart';
import 'package:wahda_bank/features/sync/infrastructure/sync_service.dart';

class _FakeGateway implements ImapGateway {
  final StreamController<ImapEvent> ctrl = StreamController<ImapEvent>();
  @override
  Stream<ImapEvent> idleStream({required String accountId, required String folderId}) => ctrl.stream;
  @override
  Future<List<HeaderDTO>> fetchHeaders({required String accountId, required String folderId, int limit = 50, int offset = 0}) async => const [];
  @override
  Future<List<HeaderDTO>> searchHeaders({required String accountId, required String folderId, required SearchQuery q}) async => const [];
  @override
  Future<BodyDTO> fetchBody({required String accountId, required String folderId, required String messageUid}) async => const BodyDTO(messageUid: '', mimeType: 'text/plain');
  @override
  Future<List<AttachmentDTO>> listAttachments({required String accountId, required String folderId, required String messageUid}) async => const [];
  @override
  Future<List<int>> downloadAttachment({required String accountId, required String folderId, required String messageUid, required String partId}) async => const [];
}

class _FakeRepo implements repo.MessageRepository {
  @override
  Future<List<Message>> fetchInbox({required Folder folder, int limit = 50, int offset = 0}) async => <Message>[];
  @override
  Future<Message> fetchMessageBody({required Folder folder, required String messageId}) async => throw UnimplementedError();
  @override
  Future<List<Attachment>> listAttachments({required Folder folder, required String messageId}) async => <Attachment>[];
  @override
  Future<List<int>> downloadAttachment({required Folder folder, required String messageId, required String partId}) async => <int>[];
  @override
  Future<void> markRead({required Folder folder, required String messageId, required bool read}) async {}
  @override
  Future<List<SearchResult>> search({required String accountId, required SearchQuery q}) async => <SearchResult>[];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('idle_loop sampler starts/stops across IDLE window', () async {
    final gw = _FakeGateway();
    final repo = _FakeRepo();
    final svc = SyncService(gateway: gw, messages: repo);
    unawaited(svc.start(accountId: 'acc', folderId: 'INBOX'));
    // Emit a couple of events then close
    gw.ctrl.add(const ImapEvent(type: ImapEventType.exists, folderId: 'INBOX'));
    gw.ctrl.add(const ImapEvent(type: ImapEventType.flagsChanged, folderId: 'INBOX'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await gw.ctrl.close();
    // Let onDone run
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await svc.stop();
  });

  test('bg_fetch_ios_cycle sampler wraps coalesced run', () async {
    final repo = _FakeRepo();
    final cb = CircuitBreaker();
    final bus = _NoopBus();
    final bg = BgFetchIos(messages: repo, circuitBreaker: cb, bus: bus, registerFn: () async => true);
    await bg.start();
    bg.tick(folderId: 'INBOX');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  });

  test('reconnect_window sampler wraps connectivity regain refresh', () async {
    final repo = _FakeRepo();
    final cb = CircuitBreaker();
    final streamCtrl = StreamController<List<ConnectivityResult>>();
    final mon = ConnectivityMonitor(messages: repo, circuitBreaker: cb, stream: streamCtrl.stream);
    unawaited(mon.start(folderId: 'INBOX'));
    streamCtrl.add(<ConnectivityResult>[ConnectivityResult.wifi]);
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    await mon.stop();
    await streamCtrl.close();
  });
}

class _NoopBus implements SyncEventBus {
  @override
  void publishBgFetchTick({required String folderId}) {}

  @override
  void publishNewMessageArrived({required String folderId}) {}

  @override
  void publishSyncFailed({required String folderId, required String errorClass}) {}
}
