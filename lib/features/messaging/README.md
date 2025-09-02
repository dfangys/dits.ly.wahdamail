# Messaging Feature (P2)

P2 adds the first infrastructure slice for headers-only messaging with a header-first strategy. No user-visible changes. All DDD flags remain OFF by default and legacy services remain active.

Scope (P2)
- Gateways (headers-only): IMAP adapter over enough_mail, SMTP stub
- Local store: metadata-only DTOs and an in-memory DAO (indexes defined for future SQLite/Isar)
- Mappers: DTO ⇄ domain
- Repository: IMAP message repository (headers path)
- Facade: DddMailServiceImpl behind a feature flag
- DI: Chooses legacy unless ddd.messaging.enabled == true (flag remains false by default)
- Tests: adapter mapping, DTO/domain round-trip, repository behavior (in-memory store + mocked gateway)

Data flow (P2)
Gateway (IMAP headers) → Repository (header-first) → Local Store (persist metadata) → Domain models returned

Files
- domain
  - entities: Message, Folder, (Flags embedded)
  - repositories (interfaces): MessageRepository
- application
  - facade: MessagingFacade (fetchInbox)
- infrastructure
  - gateways: infrastructure/gateways/imap_gateway.dart, smtp_gateway.dart
  - datasource: infrastructure/datasources/local_store.dart (InMemoryLocalStore)
  - dtos: infrastructure/dtos/message_row.dart (metadata only)
  - mappers: infrastructure/mappers/message_mapper.dart
  - repo: infrastructure/repositories_impl/imap_message_repository.dart
  - facade: infrastructure/facade/ddd_mail_service_impl.dart, infrastructure/facade/legacy_messaging_facade.dart
  - di: infrastructure/di/messaging_module.dart (flag-based facade selection)

Indexes (for future persistent store)
- date DESC
- (from, subject)
- (flags, date)

Flags
- ddd.messaging.enabled: false (do not flip in P2)

Notes
- No Flutter or external SDK imports in domain and application layers.
- Gateways and DI live in infrastructure and may depend on enough_mail and GetStorage.
- Pins unchanged: enough_mail: 2.1.7, enough_mail_flutter: 2.1.1

