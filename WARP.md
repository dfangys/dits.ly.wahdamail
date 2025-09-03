# WARP Guide: Wahda Bank Mail Client

This document orients future Warp sessions working on the Flutter email client in this repository.

Project root: /Users/dits/Downloads/wahdaapp/dits.ly.wahdamail


## Quick start: common commands

Run and develop

- flutter pub get
- flutter run
- flutter run -d chrome
- flutter analyze
- dart format .

Testing

- flutter test
- flutter test test/widget_test.dart  # single file

Build for production

- flutter build apk --release
- flutter build ios --release
- flutter build web --release

Other helpful

- flutter pub outdated
- flutter pub upgrade --major-versions


## Architecture overview

Pattern: Clean Architecture with MVVM using GetX for state management and DI.

Top-level structure under lib/

- app/
  - bindings/: Dependency injection bindings
  - controllers/: GetX controllers (e.g., MailBoxController)
  - routes/: Routing configuration
- infrastructure/: API clients (e.g., mailsys_api_client.dart)
- middleware/: Middlewares (e.g., AuthMiddleware)
- models/: Data models and SQLite helpers/storage
- services/: Core services (mail_service, cache_manager, realtime_update_service, etc.)
- utils/ (or utills/): Utilities and constants
- views/: Screens and feature UIs (compose, settings, mailbox views)
- widgets/: Reusable UI components

Separation of concerns

- UI: lib/views and lib/widgets
- Application: lib/app (controllers, bindings, middleware)
- Domain: lib/models and lib/services
- Infrastructure: lib/infrastructure (API clients, adapters)


## Key services and patterns

- MailService: central IMAP/SMTP handling (enough_mail pinned ~2.1.x, core 2.1.7). Responsible for connect, fetch, flags, delete, and sync.
- RealtimeUpdateService: event-driven updates via IMAP IDLE + Rx/GetX streams.
- OptimizedIdleService: robust IMAP IDLE with backoff, health checks, and reconnect logic.
- CacheManager + PreviewService: multi-level caching, preview generation to keep UI snappy.
- BackgroundService: Workmanager integration for periodic checks (Android) + notifications.
- ConnectionManager: network-aware reconnect strategies.
- ImapCommandQueue + ImapFetchPool: serialize heavy commands; allow safe concurrent light fetches.
- AuthMiddleware: route guards tied to SettingsController state (auth/app lock).


## Drafts workflow (local + server)

Core files (paths may vary):

- lib/models/sqlite_draft_repository.dart: Drafts CRUD, sync state, scheduling, tags, reactive streams.
- lib/models/sqlite_database_helper.dart: Drafts table schema, indices, migrations, transactions.
- lib/views/compose/models/draft_model.dart: Rich draft model (recipients, attachments, schedule, sync state), DB/MIME conversions.
- lib/views/compose/controller/compose_controller.dart: Draft lifecycle (autosave, schedule, categorize, recover, discard), attachment handling, robust error handling, server append + hydration.
- lib/services/draft_sync_service.dart: UI badge states for sync progress/errors.
- lib/services/scheduled_send_service.dart: Scheduled local drafts → SMTP send, clean-up.
- lib/models/sqlite_mime_storage.dart: Stores envelopes/metadata, batch ops, listeners, data-change notifications.
- lib/views/compose/widgets/modern_draft_options_sheet.dart: UI options for save/discard/schedule/categorize.

Notable behaviors

- Autosave: debounced and content-aware; marks drafts dirty/clean.
- Server append + proactive hydration: after append, fetch new envelope via ImapFetchPool and notify RealtimeUpdateService → instant UI update.
- Offline-first: local SQLite is authoritative for drafts; server failures fall back gracefully; sync markers retained.
- Scheduled send: periodic check, send at scheduled time; delete local scheduled drafts on success.

Recent quality fixes

- Removed unnecessary non-null assertions in compose controller around drafts usage; analyzer warnings cleared.


## Testing

- Unit/widget tests: flutter test
- Single test file: flutter test test/widget_test.dart
- Consider coverage: flutter test --coverage (if needed)
- Lints: flutter analyze (resolve warnings in controllers/services/widgets over time)


## Build targets

- Android: flutter build apk --release
- iOS: flutter build ios --release
- Web: flutter build web --release

Common setup

- Ensure Flutter SDK and platform toolchains are installed and configured (Android SDK/Xcode).
- On iOS, open ios/ in Xcode for signing if needed.


## Troubleshooting and tips

- Analyzer warnings: Run flutter analyze regularly. Many warnings are benign but should be iteratively reduced for quality (e.g., unnecessary non-null assertions, unused fields/elements, deprecated usage).
- Dependency constraints: pub outdated can show newer versions; update carefully due to pinned email stack (enough_mail 2.1.x). Test IMAP/SMTP paths thoroughly after upgrades.
- IMAP IDLE reliability: OptimizedIdleService handles reconnects/backoff. If real-time updates lag, inspect logs and connection health.
- Background tasks (Android): Workmanager scheduling depends on OS constraints (Doze); ensure constraints and notifications are configured.
- Attachments: Thumbnail generation and PDF handling rely on services with some deprecated members; plan refactors when upgrading media libs.


## How Warp should operate in this repo

- Prefer non-interactive, non-paginated commands (e.g., git --no-pager ...).
- Use absolute paths or relative paths from repo root. Avoid changing directories in commands unless necessary.
- When editing code, ensure upstream/downstream dependencies are updated and adhere to existing patterns.
- For large files, fetch only the needed ranges when reviewing; for >5000 lines, chunk reads.
- After code changes, consider running analyzer/tests. Ask before building release artifacts unless requested.
- Handle secrets via environment variables when commands require them; never inline secrets in command strings.


## Documentation

- docs/ARCHITECTURE.md: System and module design.
- docs/DEVELOPMENT.md: Dev workflow, commands, testing and coverage.
- docs/TROUBLESHOOTING.md: Known issues and debugging strategies.
- README.md: Overview, features, quick start, architecture summary.


## Notes on the email stack

- IMAP/SMTP via enough_mail (core ~2.1.7); flutter bindings in enough_mail_flutter (2.1.x). The ecosystem is sensitive to version drift; avoid major updates without full regression tests on connect/fetch/flags/append/idle flows.


## Useful git commands

- git --no-pager log --oneline -n 20
- git --no-pager diff HEAD~1
- git add -A && git commit -m "message"
- git status --porcelain=v1


## Next steps for contributors

- Get familiar with compose_controller.dart and MailBoxController for core flows.
- Review services: MailService, RealtimeUpdateService, DraftSyncService, ScheduledSendService.
- Run the app, create/edit/schedule drafts, and verify real-time updates.
- Address analyzer warnings incrementally and add tests where missing.

