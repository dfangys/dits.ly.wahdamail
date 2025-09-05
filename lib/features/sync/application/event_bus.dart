/// Application-level event bus for sync events (interface only in P5/P14).
abstract class SyncEventBus {
  void publishNewMessageArrived({required String folderId});
  void publishSyncFailed({
    required String folderId,
    required String errorClass,
  });
  void publishBgFetchTick({required String folderId});
}

/// Marker event for background fetch tick (metrics only in P14).
class BgFetchTick {
  final String folderId;
  final DateTime when;
  BgFetchTick({required this.folderId, DateTime? when})
    : when = when ?? DateTime.now();
}

/// No-op implementation for P5/P14 (shadow mode; no UI/notifications).
class NoopSyncEventBus implements SyncEventBus {
  @override
  void publishNewMessageArrived({required String folderId}) {}

  @override
  void publishSyncFailed({
    required String folderId,
    required String errorClass,
  }) {}

  @override
  void publishBgFetchTick({required String folderId}) {}
}
