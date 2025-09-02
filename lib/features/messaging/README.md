# Messaging Feature (P1)

This feature defines the domain model and application use cases for messaging under DDD + Clean Architecture. No behavior changes are introduced; the code is not wired to controllers and all DDD flags remain off by default.

Layers
- domain
  - entities: Message, Folder, Thread
  - value_objects: EmailAddress, Flags
  - events: NewMessageArrived, MessageSent
  - repositories (interfaces): MessageRepository, FolderRepository, OutboxRepository
- application
  - usecases: FetchInbox, FetchMessageBody, SendEmail, SyncFolder, MarkRead
- infrastructure/presentation
  - None added in P1 (out of scope)

Notes
- No Flutter or external SDK imports in domain and application layers.
- Repository interfaces are pure domain contracts.
- Use cases are orchestration only; infra implementations will come in later phases.

