# Messaging Feature (P3)

P3 adds bodies and attachments with lazy load + cache. No user-visible changes. All DDD flags remain OFF by default; legacy services continue to power UI.

Scope (P3)
- Gateways (IMAP only): fetchBody, listAttachments, downloadAttachment; map errors to taxonomy; no SDK types leak.
- Local store: BodyRow and AttachmentRow + blob cache APIs; bodies and attachments stored separately from headers.
- Repository: cache-first for body; list attachments and idempotent download (no re-download if cached).
- Mappers: BodyDTO ⇄ BodyRow ⇄ domain BodyContent; AttachmentDTO ⇄ AttachmentRow ⇄ domain Attachment.
- DI: existing bindings extended for store/repo (flags remain false).
- Tests: adapter error mapping, repository cache behavior, mappers.

Data flow (P3)
Gateway (body/attachments) → Repository (lazy fetch/caching) → Store (persist body/attachments) → Domain models

Files (added/updated in P3)
- domain
  - entities: BodyContent, Attachment
  - repositories: MessageRepository (listAttachments, downloadAttachment)
- infrastructure
  - gateways: infrastructure/gateways/imap_gateway.dart (+ BodyDTO, AttachmentDTO)
  - datasource: infrastructure/datasources/local_store.dart (+ Body/Attachment APIs)
  - dtos: infrastructure/dtos/body_row.dart, infrastructure/dtos/attachment_row.dart
  - mappers: infrastructure/mappers/message_mapper.dart (+ body/attachment mappers)
  - repo: infrastructure/repositories_impl/imap_message_repository.dart (+ caching paths)

Cache policy (doc-only in P3)
- Bodies/attachments kept in a simple LRU cache with a global cap (e.g., 20 MB)
- Idempotent attachment download: re-requests are no-ops if cached

Flags
- ddd.messaging.enabled: false (do not flip in P3)

Notes
- No Flutter or external SDK imports in domain and application layers.
- Gateways and DI live in infrastructure and may depend on enough_mail and GetStorage.
- Pins unchanged: enough_mail: 2.1.7, enough_mail_flutter: 2.1.1

