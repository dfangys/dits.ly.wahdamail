# P25: Performance sampling — mailbox/search lists

Goal
- Instrument mailbox/search lists with lightweight frame/scroll telemetry and apply safe list tuning (cacheExtent/itemExtent) to validate jank budgets.
- No visual or behavior changes. Flags remain OFF; kill-switch has precedence.

What was added
- list sampler: lib/observability/perf/list_perf_sampler.dart
  - Captures FrameTiming while active and derives dropped frame percentage (>=16.7 ms budget).
  - Tracks instantaneous scroll velocity (px/s) from a ScrollController and reports median velocity.
  - Emits a single telemetry event on stop() with fields: op, latency_ms, jank_frames, total_frames, dropped_pct, scroll_velocity_px_s, request_id (optional).
- Hooks:
  - EnhancedMailboxView (mailbox list): start on appear, stop on dispose.
  - SearchView (search results list): start on appear, stop on dispose.
  - Ops: mailbox_list_scroll, search_list_scroll.
- Safe list tuning (no layout change):
  - Search list: cacheExtent ~3 rows (360 px).
  - Mailbox list: cacheExtent reduced to ~3 rows when existing tuning feature flag enables virtualization.
- Dev scripts:
  - scripts/perf/sample_mailbox_scroll.dart: filters list scroll telemetry lines from flutter run output.
  - scripts/perf/parse_frame_timings.dart: computes p50/p95 dropped frame percentages from telemetry lines.

How to run
1) Run the app and capture logs, then parse budgets:
   flutter run -d <device> | \
     dart run scripts/perf/sample_mailbox_scroll.dart | \
     dart run scripts/perf/parse_frame_timings.dart

2) Alternatively, capture to a file then parse:
   flutter run -d <device> > /tmp/run.log
   dart run scripts/perf/parse_frame_timings.dart /tmp/run.log

Telemetry fields
- op: mailbox_list_scroll | search_list_scroll
- latency_ms: total sampling duration
- jank_frames: number of frames exceeding the 16.7 ms budget (best-effort)
- total_frames: total sampled frames
- dropped_pct: (jank_frames / total_frames) * 100 (approximation)
- scroll_velocity_px_s: median scroll velocity over the sampling window
- request_id: optional correlation id if available

Budgets (observe only)
- mailbox_list_scroll_dropped_pct_p50 <= 5%
- search_list_scroll_dropped_pct_p50 <= 5%

Guardrails
- No domain/app logic changes. No new dependencies.
- Import enforcer remains in effect: no new Colors.* usage in presentation/views (DS/theme excluded).
- Flags OFF; kill-switch has precedence.

Notes
- Dropped frame percentage is a best-effort proxy using frame total span vs a 60Hz budget.
- The sampler emits one event per view lifetime; capture enough samples to stabilize p50/p95.

---

P26: Compose editor & attachments (no feature change)
- Sampler: lib/observability/perf/compose_perf_sampler.dart
  - Emits ops compose_editor_interaction (screen visible) and compose_attachments_scroll (using route’s primary scroll controller).
  - Fields: op, latency_ms, jank_frames, total_frames, dropped_pct, request_id (optional)
- Hooks:
  - Start on appear; stop on dispose in the compose shell.
- Dev script:
  - scripts/perf/sample_compose.dart
- Budgets (observe only):
  - compose_editor_dropped_pct_p50 <= 5%
  - attachments_scroll_dropped_pct_p50 <= 5%
- How to run:
  flutter run -d <device> | \
    dart run scripts/perf/sample_compose.dart | \
    dart run scripts/perf/parse_frame_timings.dart

---

P27: Message detail render & scroll (no feature change)
- Sampler: lib/observability/perf/message_detail_perf_sampler.dart
  - Ops: message_detail_render (screen visible) and message_detail_body_scroll (primary ScrollController).
  - Fields: op, latency_ms, jank_frames, total_frames, dropped_pct, request_id (optional)
- Hooks:
  - Start render op on first frame; stop on dispose.
  - Attach scroll op to primary scroll; stop on dispose.
- Budgets (observe only):
  - message_detail_render_dropped_pct_p50 <= 5%
  - message_detail_body_scroll_dropped_pct_p50 <= 5%
- How to run:
  flutter run -d <device> | dart run scripts/perf/parse_frame_timings.dart

---

P28: Background perf sampling — sync/idle & bg_fetch (no feature change)
- Sampler: lib/observability/perf/bg_perf_sampler.dart
  - Ops: idle_loop (IMAP IDLE alive), fetch_headers_batch (header batch), bg_fetch_ios_cycle (iOS BG fallback), reconnect_window (connectivity regain coalesced refresh)
  - Fields: op, latency_ms, jank_frames, total_frames, dropped_pct, request_id (optional)
- Hooks:
  - SyncService: start idle_loop on IDLE subscribe; stop on error/done. Wrap header batch fetches with fetch_headers_batch.
  - BgFetchIos: start bg_fetch_ios_cycle on coalesced run; stop in finally.
  - ConnectivityMonitor: start reconnect_window on regain; stop after refresh completes.
- How to run:
  flutter run -d <device> | \
    dart run scripts/perf/sample_sync.dart | \
    dart run scripts/perf/parse_frame_timings.dart
- Budgets (observe only):
  - idle_loop_dropped_pct_p50 <= 5%
  - fetch_headers_batch_dropped_pct_p50 <= 5%
  - bg_fetch_ios_cycle_dropped_pct_p50 <= 5%
  - reconnect_window_dropped_pct_p50 <= 5%

