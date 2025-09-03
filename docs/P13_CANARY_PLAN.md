# P13 Canary Plan (no flag flips; docs + scripts)

Objective
- Prepare a safe, observable canary rollout for ViewModel-driven presentation without enabling features by default.
- Keep ddd.send.enabled OFF. Limit ddd.search.enabled and ddd.messaging.enabled (prefetch only) to a small internal cohort.

Flag Matrix (keys + defaults)
- ddd.kill_switch.enabled = false    # hard override to legacy when true
- ddd.search.enabled = false         # canary target: 5% internal
- ddd.messaging.enabled = false      # prefetch only; 5% internal
- ddd.send.enabled = false           # remain OFF in P13

Flags and Targets (for canary)
- ddd.kill_switch.enabled: master kill; must supersede all flags.
- ddd.search.enabled: 5% internal testers.
- ddd.messaging.enabled (prefetch only): 5% internal testers.
- ddd.send.enabled: OFF (0%).

Cohort Selection (deterministic)
- Deterministic selection by percent:
  - percent = djb2Hash(accountEmail) % 100
  - In cohort if percent < rolloutPercent (e.g., 5)

Example code (debug-only):
```dart
import 'package:wahda_bank/shared/utils/hashing.dart';

bool isInCohort(String email, int rolloutPercent) {
  final h = Hashing.djb2(email).abs();
  return (h % 100) < rolloutPercent;
}
```

Copy-paste cohort snippet (standalone):
```dart
int djb2Hash(String s) {
  var h = 5381;
  for (final c in s.codeUnits) { h = ((h << 5) + h) + c; } // h*33 + c
  return h & 0x7fffffff;
}
bool inCohort(String email, int percent) => djb2Hash(email) % 100 < percent;
```

Cohort Strategy (internal only)
- Limit by tester list (hashed account IDs) or by deterministic percent above, and/or by internal build flavor.
- Example approach (app reads GetStorage):
  - testers.allowlist: ["<hash1>", "<hash2>"]
  - The app computes Hashing.djb2(accountEmail) and checks membership.

Guardrails & Observability Checklist
- request_id: attach to every user action (search, inbox open, send). Use stable IDs in tests.
- error_class: ensure all failure paths map to taxonomy (AuthError, TransientNetworkError, RateLimitError, PermanentProtocolError).
- budgets (latencies):
  - inbox_open_ms: < 1200 ms p95 (cold open); gate p50 ≤ 600 ms
  - search latency: < 1500 ms p95 (server merge allowed)
  - attachment fetch: < 3000 ms p95 (large payloads)
- success gates (proceed after 24h):
  - error_rate(search|fetch|send) < 1%
  - inbox_open_ms_p50 ≤ 600 ms
- abort gates (immediate):
  - error_rate(search|fetch|send) > 2% for 15m
  - inbox_open_ms_p50 > 600 ms for 30m
- events to watch (daily):
  - search_success/search_failure
  - inbox_open_ms (distribution)
  - send_success/send_failure (send remains off for canary)
- backpressure behavior: no crashes on network timeouts; degraded UX allowed.

Dashboards (existing fields)
- Fields: request_id, op, folder_id, lat_ms, error_class, cache
- Example queries (pseudocode):
  - inbox_open_ms_p50: percentile(lat_ms, 50) where op = 'inbox_open'
  - message_open_ms_p50_cached: percentile(lat_ms, 50) where op = 'message_open' and cache = 'hit'
  - sync_cycle_ms_p50: percentile(lat_ms, 50) where op = 'sync_cycle'
  - search_success_rate: count(op='search' and event='success') / count(op='search')

Instant Kill-Switch Procedure
- If KPIs regress or error_class spikes:
  1) Set ddd.kill_switch.enabled = true (disables all DDD routing immediately)
  2) Confirm legacy paths are active in telemetry (path: legacy)
  3) File incident with last request_id samples and top error_class

Dry-run checks (no hard-coded flips in code)
- git grep -n "ddd\.(search|messaging|send)\.enabled\s*:\s*true" → must be empty
- git grep -n "ddd\.kill_switch\.enabled\s*:\s*true" → must be empty

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

Playbook: flip → verify → rollback
- Flip (internal canary 5%): ensure cohort logic and flags are in effect for internal testers only.
- Verify: watch dashboards for success/abort gates; sample request_id traces.
- Rollback: set ddd.kill_switch.enabled = true and restart the app/session; confirm legacy path via telemetry.

Privacy note
- Telemetry uses hashed identifiers (e.g., account_id_hash via djb2). No PII is logged.

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

Appendix: JSON slice
```json
{
  "canary": {
    "flags": {
      "kill_switch": "ddd.kill_switch.enabled=false",
      "search": "ddd.search.enabled=5% internal",
      "messaging_prefetch": "ddd.messaging.enabled=5% internal",
      "send": "ddd.send.enabled=false"
    },
    "cohort": "djb2Hash(accountEmail) % 100 < rolloutPercent",
    "success_gates": {
      "error_rate_max": "1% over 24h",
      "inbox_open_ms_p50": 600,
      "message_open_ms_p50_cached": 200,
      "sync_cycle_ms_p50": 1500
    },
    "abort_gates": {
      "error_rate": "> 2% for 15m",
      "inbox_open_ms_p50": "> 600ms for 30m"
    },
    "telemetry_fields": ["request_id","op","folder_id","lat_ms","error_class","cache"],
    "kill_switch": "flip ddd.kill_switch.enabled=true → forces legacy everywhere",
    "dry_run_checks": [
      "git grep -n \"ddd\\.(search|messaging|send)\\.enabled\\s*:\\s*true\"",
      "git grep -n \"ddd\\.kill_switch\\.enabled\\s*:\\s*true\""
    ]
  }
}
```

