# Sync Feature (P5)

P5 introduces a shadow-mode sync service that listens for IMAP IDLE-like events and triggers header-first fetches in the DDD messaging repository. No UI dispatch, notifications, or background integration.

Components
- Application
  - event_bus.dart: SyncEventBus interface and NoopSyncEventBus
- Infrastructure
  - sync_service.dart: consumes ImapGateway.idleStream and calls MessageRepository.fetchInbox on events (exists/expunge/flagsChanged)
  - sync_scheduler.dart: simple start/stop orchestration (no WorkManager yet)

Flow (shadow)
ImapGateway.idleStream → SyncService (shadow) → MessageRepository.fetchInbox(headers) → LocalStore (DDD)

Backoff
- Jittered backoff used for retry on stream errors/closures
- Tested in jitter_backoff_test.dart

Flags
- ddd.sync.shadow_mode must be true AND ddd.messaging.enabled must be false to start automatically
- Defaults remain false; no flag flips in P5

