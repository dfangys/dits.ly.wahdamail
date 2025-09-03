# Sync Feature (P5, P14)

P5 introduces a shadow-mode sync service that listens for IMAP IDLE-like events and triggers header-first fetches in the DDD messaging repository. No UI dispatch, notifications, or background integration.

P14 adds iOS background fallback and connectivity awareness:
- When iOS background throttles IMAP IDLE, schedule BGAppRefresh via Workmanager and coalesce ticks within 3–5s.
- A CircuitBreaker prevents hammering flaky networks and moves open→half-open→closed with jittered reopen.
- A ConnectivityMonitor resets the breaker and triggers a single header refresh on regain (debounced).

Components
- Application
  - event_bus.dart: SyncEventBus interface and NoopSyncEventBus (adds BgFetchTick event type in P14)
- Infrastructure
  - sync_service.dart: consumes ImapGateway.idleStream and calls MessageRepository.fetchInbox on events (exists/expunge/flagsChanged)
  - sync_scheduler.dart: simple start/stop orchestration (no WorkManager yet)
  - bg_fetch_ios.dart (P14): coalesced header refresh driver + Workmanager registration (idempotent)
  - circuit_breaker.dart (P14): half-open breaker with jittered reopen
  - connectivity_monitor.dart (P14): debounced refresh on connectivity regain

Flow
- Shadow: ImapGateway.idleStream → SyncService → MessageRepository.fetchInbox(headers) → LocalStore
- iOS BG (P14): Workmanager BG tick(s) → BgFetchIos.coalesce → MessageRepository.fetchInbox(headers)

Telemetry
- op=bg_fetch, {folder_id, fetched_count, lat_ms, error_class?, coalesced}
- IdleLoop metrics retained for shadow path

Backoff
- Jittered backoff used for retry on stream errors/closures
- CircuitBreaker in P14 protects BG path; half-open single trial after open period

Flags
- ddd.sync.shadow_mode must be true AND ddd.messaging.enabled must be false to start automatically (P5)
- ddd.ios.bg_fetch.enabled must be true AND kill-switch false to start BG fallback (P14)
- Defaults remain false; no flag flips

24h iOS BG fallback check (P17 doc)
- Goal: Validate that, over 24h, BG fetch coalesces and does not exceed battery/db budgets.
- How to capture:
  1) Enable BG fallback (internal build; do not flip in prod). Ensure telemetry is collected locally.
  2) Collect logs for 24h and export to a text file (e.g., device syslog or app log output with telemetry lines).
  3) Run: `dart run scripts/observability/sample_budget_check.dart < logs.txt`
- Expected result format:
  - search_success_rate: float in [0,1]
  - inbox_open p50/p95 ms
  - fetch_body p50/p95 ms
  - search p50/p95 ms
- Evaluation:
  - inbox_open_ms_p50 ≤ 600ms
  - message_open_ms_p50_cached ≤ 200ms (approximate via fetch_body cache hits)
  - sync_cycle_ms_p50 ≤ 1500ms (from Sync telemetry if available)
  - db_size_mb_cap ≤ 800MB (from storage tools)

