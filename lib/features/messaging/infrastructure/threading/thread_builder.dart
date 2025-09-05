import 'package:wahda_bank/features/messaging/infrastructure/datasources/local_store.dart';
import 'package:wahda_bank/features/messaging/domain/value_objects/thread_key.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';

class ThreadAggregate {
  final ThreadKey key;
  final List<String> messageUids;
  const ThreadAggregate({required this.key, required this.messageUids});
}

/// ThreadBuilder: builds thread aggregates from headers in LocalStore.
class ThreadBuilder {
  final LocalStore store;
  ThreadBuilder(this.store);

  Future<List<ThreadAggregate>> build({
    required String folderId,
    String? requestId,
  }) async {
    final sw = Stopwatch()..start();
    final rows = await store.getHeaders(
      folderId: folderId,
      limit: 10000,
      offset: 0,
    );
    final map = <ThreadKey, List<String>>{};
    for (final r in rows) {
      final key = ThreadKey.fromHeaders(
        messageId: r.messageIdHeader,
        inReplyTo: r.inReplyTo,
        references: r.references,
        subject: r.subject,
      );
      map.putIfAbsent(key, () => <String>[]).add(r.id);
    }
    final aggs =
        map.entries
            .map(
              (e) => ThreadAggregate(key: e.key, messageUids: e.value..sort()),
            )
            .toList();
    Telemetry.event(
      'operation',
      props: {
        'op': 'ThreadBuild',
        'folder_id': folderId,
        'count': aggs.length,
        if (requestId != null) 'request_id': requestId,
        'lat_ms': sw.elapsedMilliseconds,
      },
    );
    return aggs;
  }
}
