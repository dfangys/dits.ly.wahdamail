# Messaging Feature (P4)

P4 adds sending: drafts, outbox queue, and SMTP send (flags OFF; no UI changes).

Scope (P4)
- Domain
  - entities: OutboxItem (id, accountId, folderId, messageId, attemptCount, status {queued,sending,sent,failed}, lastErrorClass?, retryAt?, createdAt, updatedAt)
  - value_objects: RetryPolicy (backoff: 1m, 5m, 30m, 2h; capped at 24h)
  - repositories: OutboxRepository (enqueue, nextForSend, markSending, markSent/markFailed, listByStatus), DraftRepository (saveDraft, getDraftById)
- Infrastructure
  - SMTP gateway: send({accountId, rawBytes}) → Message-Id; map errors to AuthError/TransientNetworkError/RateLimitError/PermanentProtocolError
  - Local store: OutboxRow, DraftRow + in-memory DAO; idempotent writes; separate from headers/bodies
  - Repos: OutboxRepositoryImpl, DraftRepositoryImpl
- Application
  - usecases/send_email.dart: Save/ensure draft → enqueue outbox → attempt send via SmtpGateway → mark sent/failed with RetryPolicy
- Tests
  - Adapter: SMTP error mapping
  - Repo: enqueue/nextForSend/transitions/backoff/idempotency
  - Use case: success and failure paths

Send flow (P4)
Draft → Outbox (queued) → mark sending → SMTP send → mark sent | mark failed (+retryAt per policy)

Retry policy (doc)
- Backoff schedule: 1m, 5m, 30m, 2h; capped at 24h

Flags
- ddd.messaging.enabled: false (do not flip)

Notes
- No Flutter or external SDK imports in domain and application layers.
- Pins unchanged: enough_mail: 2.1.7, enough_mail_flutter: 2.1.1

Shadow sync (P5)
ImapGateway.idleStream → SyncService → MessageRepository.fetchInbox(headers) → LocalStore (DDD); metrics only (no UI/notifications)

Search (P6)
- Fields supported: from, to, subject, text (body-if-cached), dateFrom/dateTo, flags, limit
- Value object: SearchQuery normalizes inputs (lowercase, trims, de-dupes flags)
- Result entity: SearchResult (messageId, folderId, date, optional score)
- Local-first strategy: LocalStore.searchMetadata; optional remote search via ImapGateway.searchHeaders (stubbed, disabled by default). Results are merged with local, de-duplicated, sorted by date DESC, then limited.
- No DB schema/FTS changes in P6; FTS may come later

P15: Mail domain edges (flags OFF; no UI)
- Threading (RFC 5322): ThreadBuilder aggregates messages by Message-ID/In-Reply-To/References; falls back to normalized subject only when headers are missing. ThreadKey is deterministic.
- Special-use folders (RFC 6154): SpecialUseMapper maps \Inbox, \Sent, \Trash, \Junk, \Archive, \Drafts; tenant overrides supported via DI.
- MIME robustness: MimeDecoder handles quoted-printable, base64, and common charsets (UTF-8, ISO-8859-1, windows-1252/1256 best-effort). CID links preserved; no remote fetch.
- UID window sync: UidWindowSync computes moving UID ranges and persists highest-seen per folder via LocalStore; resumes safely without duplicates.
- Flag conflict resolution: last-writer-wins with server authority; on STORE conflicts retry using server snapshot.
- Telemetry ops: ThreadBuild, SpecialUseMap, MimeDecode, UidWindowSync, FlagConflictResolve with fields {request_id, op, folder_id, count?, lat_ms, error_class?}.

