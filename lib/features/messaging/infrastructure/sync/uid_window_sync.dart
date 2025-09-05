import 'package:wahda_bank/features/messaging/infrastructure/datasources/local_store.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';

class UidRange {
  final int start;
  final int end;
  const UidRange(this.start, this.end);
}

/// Helper for windowed UID sync in large folders.
class UidWindowSync {
  final ImapGateway gateway;
  final LocalStore store;
  final int defaultWindow;
  UidWindowSync({
    required this.gateway,
    required this.store,
    this.defaultWindow = 500,
  });

  /// Compute next UID window(s) to fetch based on highest seen and remote max.
  Future<List<UidRange>> nextWindows({
    required String folderId,
    required int remoteMaxUid,
    int? windowSize,
    String? requestId,
  }) async {
    final sw = Stopwatch()..start();
    final size = windowSize ?? defaultWindow;
    final highest = await store.getHighestSeenUid(folderId: folderId) ?? 0;
    if (remoteMaxUid <= highest) {
      Telemetry.event(
        'operation',
        props: {
          'op': 'UidWindowSync',
          'folder_id': folderId,
          'count': 0,
          'lat_ms': sw.elapsedMilliseconds,
          if (requestId != null) 'request_id': requestId,
        },
      );
      return const <UidRange>[];
    }
    final ranges = <UidRange>[];
    int start = highest + 1;
    while (start <= remoteMaxUid) {
      final end =
          (start + size - 1) <= remoteMaxUid
              ? (start + size - 1)
              : remoteMaxUid;
      ranges.add(UidRange(start, end));
      start = end + 1;
    }
    Telemetry.event(
      'operation',
      props: {
        'op': 'UidWindowSync',
        'folder_id': folderId,
        'count': ranges.length,
        'lat_ms': sw.elapsedMilliseconds,
        if (requestId != null) 'request_id': requestId,
      },
    );
    return ranges;
  }

  /// Persist the highest UID after a successful window fetch.
  Future<void> recordProgress({
    required String folderId,
    required int fetchedMaxUid,
  }) async {
    await store.setHighestSeenUid(folderId: folderId, uid: fetchedMaxUid);
  }
}
