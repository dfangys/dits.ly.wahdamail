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

