# Risks and Mitigations

This document summarizes key risks introduced by the new performance work (SQLite-backed storage, pagination, background preview generation, and UI optimizations) and mitigation strategies, including rollback guidance.

## Database migrations and schema
- Risk: Migration failures or partial data due to device interruptions or old installs with divergent schema
- Mitigations:
  - Defensive migrations in sqlite_database_helper.dart ensure columns are added conditionally and indexes are created with IF NOT EXISTS
  - Day-bucket backfill is done via simple SQL UPDATE, tolerant to missing dates
  - Rollback: For a mailbox with corrupted rows, delete rows for that mailbox_id from emails table and allow app to re-sync envelopes; mailbox metadata remains intact

## WAL mode and storage constraints
- Risk: WAL journal may increase temporary disk usage during burst writes
- Mitigations:
  - PRAGMA journal_mode=WAL with PRAGMA synchronous=NORMAL to balance performance and durability
  - Batch writes are short-lived and limited; consider reducing batch sizes for low-storage devices via feature flags if needed

## Background preview generation
- Risks:
  - Excessive CPU during preview normalization on low-end devices
  - IMAP selection thrash if mailbox changes while background jobs run
- Mitigations:
  - Offload heavy normalization via compute (isolate) with bounded concurrency (maxConcurrent=2)
  - Cancel queued jobs on mailbox switch to avoid selection churn
  - Persist results (preview_text / has_attachments) and only update tiles via per-message notifier

## UI jank due to list churn
- Risks:
  - Large list updates cause heavy rebuilds
- Mitigations:
  - Per-tile ValueListenable-based updates for preview/attachments to avoid full list rebuilds
  - RepaintBoundary per row, prototypeItem to help layout
  - Animation caps for high-churn widgets

## Networking and realtime updates
- Risks:
  - Over-fetch during pagination, aggressive retries, or noisy realtime events
- Mitigations:
  - Controller uses sequence paging; realtime updates are throttled/coalesced
  - Timeouts and retries are bounded

## Feature rollout
- Risks:
  - Regressions on specific devices/OS versions
- Mitigations:
  - FeatureFlags service allows gating of: per-tile notifiers, virtualization tuning, preview worker, and animation caps
  - Use staged rollouts by toggling flags via GetStorage in QA/production builds

## CI gating and perf regressions
- Risks:
  - Subtle perf regressions land unnoticed
- Mitigations:
  - Integration perf test enforces frame budget and janky percentage configured in perf/perf_config.json
  - Fail CI on budget exceedance; archive timing summaries for regression analysis

## Operational playbook
- Rollback of preview/attachments persistence:
  - Disable preview worker via FeatureFlags; tiles fall back to existing (heavier) preview logic
- Rollback of per-tile notifiers or virtualization tuning:
  - Toggle corresponding flags off to restore prior rendering behavior
- Data corruption detection:
  - If envelope parsing fails for a mailbox, clear that mailbox’s emails from SQLite to force a clean re-sync

