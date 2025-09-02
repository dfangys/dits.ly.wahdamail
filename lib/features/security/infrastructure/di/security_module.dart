import 'package:injectable/injectable.dart';

import '../../domain/repositories/keyring_repository.dart';
import '../../domain/repositories/trust_repository.dart';
import '../../domain/services/crypto_engine.dart';
import '../../domain/services/encryption_service.dart';
import '../keyring_adapter.dart';
import '../crypto_engine_stub.dart';
import '../trust_store.dart';

@module
abstract class SecurityModule {
  @LazySingleton()
  KeyringRepository provideKeyring() => InMemoryKeyringRepository();

  @LazySingleton()
  TrustRepository provideTrust() => InMemoryTrustRepository();

  @LazySingleton()
  CryptoEngine provideCryptoEngine() => StubCryptoEngine();

  @LazySingleton()
  EncryptionService provideEncryptionService(CryptoEngine engine, KeyringRepository keyring) =>
      EncryptionService(engine: engine, keyring: keyring);
}
