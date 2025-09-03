# P13 Canary Plan (no flag flips; docs + scripts)

Objective
- Prepare a safe, observable canary rollout for ViewModel-driven presentation without enabling features by default.
- Keep ddd.send.enabled OFF. Limit ddd.search.enabled and ddd.messaging.enabled (prefetch only) to a small internal cohort.

Flags and Targets
- ddd.kill_switch.enabled: master kill; must supersede all flags.
- ddd.search.enabled: 5% internal testers.
- ddd.messaging.enabled (prefetch only): 5% internal testers.
- ddd.send.enabled: OFF (0%).

Cohort Strategy (internal only)
- Limit by tester list (hashed account IDs) or by build flavor (e.g., internal QA build).
- Example approach (app reads GetStorage):
  - testers.allowlist: ["<hash1>", "<hash2>"]
  - The app computes Hashing.djb2(accountEmail) and checks membership.

Guardrails & Observability Checklist
- request_id: attach to every user action (search, inbox open, send). Use stable IDs in tests.
- error_class: ensure all failure paths map to taxonomy (AuthError, TransientNetworkError, RateLimitError, PermanentProtocolError).
- budgets (latencies):
  - inbox_open_ms: < 1200 ms p95 (cold open)
  - search latency: < 1500 ms p95 (server merge allowed)
  - attachment fetch: < 3000 ms p95 (large payloads)
- events to watch (daily):
  - search_success/search_failure
  - inbox_open_ms (distribution)
  - send_success/send_failure (send remains off for canary)
- backpressure behavior: no crashes on network timeouts; degraded UX allowed.

Instant Kill-Switch Procedure
- If KPIs regress or error_class spikes:
  1) Set ddd.kill_switch.enabled = true (disables all DDD routing immediately)
  2) Confirm legacy paths are active in telemetry (path: legacy)
  3) File incident with last request_id samples and top error_class

Example: local/test toggle commands (development only)
- The app reads GetStorage keys; during internal QA you can script a small snippet inside a debug console/test harness:

  Dart snippet (debug-only):
  ```dart
  import 'package:get_storage/get_storage.dart';
  import 'package:wahda_bank/shared/utils/hashing.dart';

  Future<void> setCanaryFlags() async {
    await GetStorage.init();
    final box = GetStorage();
    await box.write('ddd.kill_switch.enabled', false);
    await box.write('ddd.search.enabled', true);
    await box.write('ddd.messaging.enabled', true); // prefetch only on VM paths
    await box.write('ddd.send.enabled', false);

    // Example allowlist of hashed account IDs (internal testers only)
    await box.write('testers.allowlist', <String>[
      Hashing.djb2('alice.internal@wahda.com.ly').toString(),
      Hashing.djb2('bob.internal@wahda.com.ly').toString(),
    ]);
  }
  ```

Rollout Steps
- T-0: Enable canary flags to internal allowlist (5%) via build/test hooks, not in production.
- T+1 day: Review telemetry dashboards; verify budgets and error_class distribution.
- T+3 days: Expand to 10% internal if stable; otherwise kill-switch.
- Do not enable ddd.send.enabled in P13.

Risks
- Unexpected IMAP load during prefetch: protected by 5% cohort, backoff/jitter remains active.
- Legacy controller codepaths still present (deprecated) until P12.4; ensure they do not fork behavior.

Exit Criteria for P13 → P14
- p95 latencies within budgets for 3 consecutive days on canary cohort
- search and prefetch error rates within 1.5x legacy baselines
- no crash spikes linked to VM paths

