# Enterprise API (P7)

Scope
- Domain
  - Entities/VOs: AccountProfile, Signature, Contact, Token, UserId
  - Repositories: AccountsRepository, ContactsRepository, SignaturesRepository
- Application
  - Use cases: FetchAccountProfile, ListContacts, UpsertSignature, RefreshToken, ValidateSession (optional)
  - No IO or SDK types in application
- Infrastructure
  - REST gateway over MailsysApiClient (anti-corruption)
  - Error mapping: 401→AuthError, 429→RateLimitError (retry/backoff), 5xx→TransientNetworkError, else PermanentProtocolError
  - DTOs: AccountDto, ContactDto, SignatureDto, TokenDto + mappers
  - Repository impls: AccountsRepositoryImpl, ContactsRepositoryImpl, SignaturesRepositoryImpl
  - Token refresh handled inside repos/gateway; no UI prompts
- DI & Flags
  - DI module registers gateway + repos + token store
  - ddd.enterprise_api.enabled=false (no UI wiring)

Data flow
Use cases -> Repositories (domain interfaces) -> REST gateway (infra) -> MailsysApiClient

Notes
- No REST/http/dio types leak above infra.
- Local tests use fake client/gateway; no network in tests.
- Rate-limit retry uses a backoff strategy (Noop in tests).

# enterprise_api

