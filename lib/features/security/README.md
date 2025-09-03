# Security (P8)

Scope
- Domain
  - VOs: KeyId, Fingerprint, EmailIdentity, EncryptionStatus, SignatureStatus
  - Entities: KeyPair (metadata only), TrustPolicy (TrustLevel: unknown/unverified/verified)
  - Repositories: KeyringRepository, TrustRepository
  - Services: CryptoEngine (interface); EncryptionService (orchestration using CryptoEngine + KeyringRepository)
- Application
  - Use cases: DecryptMessage, VerifySignature, SignOutgoing, EncryptOutgoing (no IO/SDK)
- Infrastructure
  - Keyring adapter: In-memory implementation for tests
  - Crypto engine adapter: stub engine (no real PGP/S/MIME)
  - Trust store: In-memory implementation
- Error taxonomy additions
  - CryptoError base; DecryptionError; SignatureInvalidError; KeyNotFoundError
- DI & Flags
  - Security DI module registers keyring, trust, crypto engine (stub), and EncryptionService
  - Flags remain OFF; no UI/controller wiring

Architecture
EncryptionService -> CryptoEngine + KeyringRepository
TrustRepository manages sender trust (defaults to unknown)

Notes
- No real crypto engines in P8 (added later in P8b)
- No Flutter/SDK types leak into domain/application

# security

