import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/sync/infrastructure/bg_fetch_ios.dart';
import 'package:wahda_bank/features/sync/infrastructure/circuit_breaker.dart';
import 'package:wahda_bank/features/sync/application/event_bus.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/message_repository.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/entities/folder.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/entities/message.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/entities/attachment.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/entities/search_result.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/value_objects/search_query.dart' as dom;

class _FakeRepo implements dom.MessageRepository {
  int calls = 0;

  @override
  Future<List<dom.Message>> fetchInbox({required dom.Folder folder, int limit = 50, int offset = 0}) async {
    calls += 1;
    return <dom.Message>[];
  }

  @override
  Future<List<int>> downloadAttachment({required dom.Folder folder, required String messageId, required String partId}) =>
      throw UnimplementedError();
  @override
  Future<dom.Message> fetchMessageBody({required dom.Folder folder, required String messageId}) =>
      throw UnimplementedError();
  @override
  Future<void> markRead({required dom.Folder folder, required String messageId, required bool read}) =>
      throw UnimplementedError();
  @override
  Future<List<dom.Attachment>> listAttachments({required dom.Folder folder, required String messageId}) =>
      throw UnimplementedError();
  @override
  Future<List<dom.SearchResult>> search({required String accountId, required dom.SearchQuery q}) =>
      throw UnimplementedError();
}

class _NoopBus implements SyncEventBus {
  @override
  void publishBgFetchTick({required String folderId}) {}
  @override
  void publishNewMessageArrived({required String folderId}) {}
  @override
  void publishSyncFailed({required String folderId, required String errorClass}) {}
}

void main() {
  test('Scheduler registration is idempotent', () async {
    var registrations = 0;
    final repo = _FakeRepo();
    final cb = CircuitBreaker();
    final bus = _NoopBus();
    final bg = BgFetchIos(
      messages: repo,
      circuitBreaker: cb,
      bus: bus,
      registerFn: () async {
        registrations += 1;
        return true;
      },
    );

    await bg.start();
    await bg.start();
    expect(registrations, 1);
  });
}

