import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/sync/infrastructure/connectivity_monitor.dart';
import 'package:wahda_bank/features/sync/infrastructure/circuit_breaker.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/message_repository.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/entities/folder.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/entities/message.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/entities/attachment.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/entities/search_result.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/value_objects/search_query.dart' as dom;

class _FakeRepo implements dom.MessageRepository {
  int fetches = 0;

  @override
  Future<List<dom.Message>> fetchInbox({required dom.Folder folder, int limit = 50, int offset = 0}) async {
    fetches += 1;
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

void main() {
  test('Connectivity regain triggers single refresh (debounced)', () async {
    final repo = _FakeRepo();
    final cb = CircuitBreaker();

    // Inject a fake connectivity stream
    final ctrl = StreamController<List<ConnectivityResult>>();

    // Create monitor with injected stream
    final monitor = ConnectivityMonitor(messages: repo, circuitBreaker: cb, stream: ctrl.stream);

    await monitor.start(folderId: 'INBOX');

    // Simulate multiple regain signals within short window
    ctrl.add([ConnectivityResult.wifi]);
    ctrl.add([ConnectivityResult.ethernet]);
    ctrl.add([ConnectivityResult.mobile]);

    // Allow debounce to elapse
    await Future.delayed(const Duration(seconds: 3));

    expect(repo.fetches, 1);
    await ctrl.close();
  });
}

