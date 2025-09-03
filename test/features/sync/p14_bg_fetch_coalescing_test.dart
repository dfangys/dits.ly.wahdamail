import 'dart:async';
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
  int lastLimit = 0;
  final List<dynamic> callsLog = [];

  @override
  Future<List<dom.Message>> fetchInbox({required dom.Folder folder, int limit = 50, int offset = 0}) async {
    calls += 1;
    lastLimit = limit;
    return <dom.Message>[];
  }

  // Unused methods for this test
  @override
  Future<List<int>> downloadAttachment({required dom.Folder folder, required String messageId, required String partId}) {
    throw UnimplementedError();
  }

  @override
  Future<dom.Message> fetchMessageBody({required dom.Folder folder, required String messageId}) {
    throw UnimplementedError();
  }

  @override
  Future<void> markRead({required dom.Folder folder, required String messageId, required bool read}) {
    throw UnimplementedError();
  }

  @override
  Future<List<dom.Attachment>> listAttachments({required dom.Folder folder, required String messageId}) {
    throw UnimplementedError();
  }

  @override
  Future<List<dom.SearchResult>> search({required String accountId, required dom.SearchQuery q}) {
    throw UnimplementedError();
  }
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
  test('BG fetch coalesces multiple ticks into a single repo call', () async {
    final repo = _FakeRepo();
    final cb = CircuitBreaker(failureThreshold: 2);
    final bus = _NoopBus();
    final bg = BgFetchIos(
      messages: repo,
      circuitBreaker: cb,
      bus: bus,
      coalesceWindow: const Duration(milliseconds: 200),
      registerFn: () async => true,
    );

    // Fire rapid ticks
    bg.tick(folderId: 'INBOX');
    bg.tick(folderId: 'INBOX');
    bg.tick(folderId: 'INBOX');

    await Future.delayed(const Duration(milliseconds: 300));

    expect(repo.calls, 1);
  });
}

