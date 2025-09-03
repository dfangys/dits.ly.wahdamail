import 'package:wahda_bank/shared/logging/telemetry.dart';

/// Resolver for message flag conflicts (\Seen, \Flagged, \Answered) in multi-device scenarios.
class FlagConflictResolver {
  /// Decide final flags given local desired and server authoritative snapshot.
  /// Policy: last-writer-wins with server authority. If local differs, we attempt STORE; on conflict we retry using server snapshot.
  Map<String, bool> resolve({required Map<String, bool> localDesired, required Map<String, bool> serverFlags, String? requestId}) {
    final sw = Stopwatch()..start();
    // Start with server as base, overlay localDesired for optimistic write
    final merged = Map<String, bool>.from(serverFlags);
    for (final e in localDesired.entries) {
      merged[e.key.toLowerCase()] = e.value;
    }
    Telemetry.event('operation', props: {
      'op': 'FlagConflictResolve',
      'lat_ms': sw.elapsedMilliseconds,
      if (requestId != null) 'request_id': requestId,
    });
    return merged;
  }

  /// On STORE conflict (e.g., server reports version mismatch), take server snapshot as truth and ask caller to retry update against it.
  Map<String, bool> onStoreConflict({required Map<String, bool> serverFlags, String? requestId}) {
    final sw = Stopwatch()..start();
    Telemetry.event('operation', props: {
      'op': 'FlagConflictResolve',
      'lat_ms': sw.elapsedMilliseconds,
      if (requestId != null) 'request_id': requestId,
      'error_class': 'StoreConflict',
    });
    return Map<String, bool>.from(serverFlags);
  }
}

