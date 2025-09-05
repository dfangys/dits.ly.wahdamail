import '../value_objects/key_id.dart';
import '../value_objects/email_identity.dart';

abstract class CryptoEngine {
  Future<List<int>> decrypt({
    required List<int> ciphertext,
    required KeyId keyId,
  });
  Future<bool> verify({
    required List<int> data,
    required List<int> signature,
    required EmailIdentity signer,
  });
  Future<List<int>> sign({required List<int> data, required KeyId keyId});
  Future<List<int>> encrypt({
    required List<int> data,
    required List<EmailIdentity> recipients,
  });
}
