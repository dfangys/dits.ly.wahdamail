import '../domain/services/crypto_engine.dart';
import '../domain/value_objects/key_id.dart';
import '../domain/value_objects/email_identity.dart';
import 'package:wahda_bank/shared/error/index.dart';

class StubCryptoEngine implements CryptoEngine {
  bool simulateDecryptionFailure;
  bool verifyReturn;

  StubCryptoEngine({this.simulateDecryptionFailure = false, this.verifyReturn = true});

  @override
  Future<List<int>> decrypt({required List<int> ciphertext, required KeyId keyId}) async {
    if (simulateDecryptionFailure) {
      throw const DecryptionError('Failed to decrypt');
    }
    // Trivial identity transform for stub
    return List<int>.from(ciphertext);
  }

  @override
  Future<List<int>> encrypt({required List<int> data, required List<EmailIdentity> recipients}) async {
    return List<int>.from(data);
  }

  @override
  Future<List<int>> sign({required List<int> data, required KeyId keyId}) async {
    return [1, 2, 3];
  }

  @override
  Future<bool> verify({required List<int> data, required List<int> signature, required EmailIdentity signer}) async {
    return verifyReturn;
  }
}
