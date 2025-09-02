import '../domain/repositories/keyring_repository.dart';
import '../domain/entities/key_pair.dart';
import '../domain/value_objects/key_id.dart';
import '../domain/value_objects/email_identity.dart';

class InMemoryKeyringRepository implements KeyringRepository {
  final Map<String, KeyPair> _byId = {};

  @override
  Future<KeyPair?> findByEmail(EmailIdentity identity) async {
    try {
      return _byId.values.firstWhere((k) => k.owner.email == identity.email);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<KeyPair?> getPrivateFor(KeyId id) async {
    final k = _byId[id.value];
    return k?.hasPrivate == true ? k : null;
  }

  @override
  Future<void> importKeyPair(KeyPair key) async {
    _byId[key.id.value] = key;
  }

  @override
  Future<List<KeyPair>> list() async => _byId.values.toList(growable: false);

  @override
  Future<void> remove(KeyId id) async {
    _byId.remove(id.value);
  }
}
