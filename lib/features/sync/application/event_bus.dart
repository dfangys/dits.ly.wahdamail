/// Application-level event bus for sync events (interface only in P5).
abstract class SyncEventBus {
  void publishNewMessageArrived({required String folderId});
  void publishSyncFailed({required String folderId, required String errorClass});
}

/// No-op implementation for P5 (shadow mode; no UI/notifications).
class NoopSyncEventBus implements SyncEventBus {
  @override
  void publishNewMessageArrived({required String folderId}) {}

  @override
  void publishSyncFailed({required String folderId, required String errorClass}) {}
}

