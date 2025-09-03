# P16 — Legacy Decommission & Rollout Plan

Status: docs only; no code behavior changes; no UI; no flag flips.

Scope
- Document the decommission checklist and rollout guardrails.
- Link from ARCHITECTURE and P13 canary plan.
- Re-affirm import bans and rollback procedure.

Checklist (do not ship until all are green)
1) Legacy controllers are removed/deprecated
   - All GetX legacy controllers are @Deprecated thin adapters delegating to feature/presentation ViewModels.
   - No new dependencies on legacy controllers.
2) No presentation → MailService imports
   - Presentation must depend on ViewModels/use cases; not on legacy services.
   - Import enforcer bans are in place (see Guardrails).
3) DDD coverage complete
   - Messaging domain covers headers, body, attachments, search, send/outbox.
   - Sync domain covers idle/coalescing, shadow mode, and retries.
   - Rendering domain covers sanitizer, CID resolution, preview cache.
4) Taxonomy 100%
   - All infra failures map to shared/error/errors.dart taxonomy.
   - Telemetry error_class is set for all failure events.
5) Caches, caps, and indices
   - Bodies LRU cap 200MB; attachments per-item ≤ 100MB; total 400MB; preview LRU 100.
   - Indices created: date DESC; (from,subject); (flags,date).
6) iOS background fallback
   - BGAppRefresh via Workmanager; 3–5s coalescing; CircuitBreaker; connectivity regain debounce.
7) Observability
   - Telemetry fields: request_id, op, folder_id, count?, lat_ms, error_class?, cache?
   - Dashboards track budgets and error rates per op.
8) Rollback & kill-switch
   - Single flag: ddd.kill_switch.enabled (true → force legacy everywhere).
   - Rollback playbook below.

Guardrails (Import Enforcer)
- Global ban: shared/ddd_ui_wiring.dart
- Presentation ban: services/mail_service.dart (any presentation/* → forbidden)
- Optional: enough_mail* imports must be restricted to infrastructure/ only (documented here; can be enabled if needed).
- Enforced by: dart run tool/import_enforcer.dart

Sanity Greps (run locally; not CI)
```
git grep -n "shared/ddd_ui_wiring.dart" || true
git grep -n "services/mail_service.dart" lib/**/presentation/** || true
git grep -n "new MailService(" || true
```

Performance Budgets (steady state)
- inbox_open_ms_p50 ≤ 600ms
- message_open_ms_p50_cached ≤ 200ms
- sync_cycle_ms_p50 ≤ 1500ms
- db_size_mb_cap ≤ 800MB

Rollback Procedure
1) Flip ddd.kill_switch.enabled = true via remote/config store
2) Restart app/session as needed (flag is read on launch and on foreground)
3) Verify telemetry shows path: legacy on all ops
4) File incident with request_id samples and top error_class

Release Notes (internal)
- This phase ships docs and guardrails only. No code paths are flipped by default; kill-switch precedence remains intact.

