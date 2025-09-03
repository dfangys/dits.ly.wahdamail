import '../entities/key_pair.dart';
import '../value_objects/key_id.dart';
import '../value_objects/email_identity.dart';

abstract class KeyringRepository {
  Future<void> importKeyPair(KeyPair key);
  Future<List<KeyPair>> list();
  Future<void> remove(KeyId id);
  Future<KeyPair?> findByEmail(EmailIdentity identity);
  Future<KeyPair?> getPrivateFor(KeyId id);
}
