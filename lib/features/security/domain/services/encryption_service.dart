import 'package:wahda_bank/features/security/domain/repositories/keyring_repository.dart';
import 'package:wahda_bank/features/security/domain/services/crypto_engine.dart';
import 'package:wahda_bank/features/security/domain/value_objects/email_identity.dart';
import 'package:wahda_bank/features/security/domain/value_objects/encryption_status.dart';
import 'package:wahda_bank/features/security/domain/value_objects/signature_status.dart';
import 'package:wahda_bank/features/security/domain/value_objects/key_id.dart';
import 'package:wahda_bank/shared/error/index.dart';

class DecryptResult {
  final EncryptionStatus status;
  final List<int>? plaintext;
  const DecryptResult(this.status, this.plaintext);
}

class EncryptionService {
  final CryptoEngine engine;
  final KeyringRepository keyring;
  const EncryptionService({required this.engine, required this.keyring});

  Future<DecryptResult> decrypt({required List<int> ciphertext, required EmailIdentity recipient}) async {
    final key = await keyring.findByEmail(recipient);
    if (key == null || !key.hasPrivate) {
      throw const KeyNotFoundError('Private key not found');
    }
    try {
      final pt = await engine.decrypt(ciphertext: ciphertext, keyId: key.id);
      return DecryptResult(EncryptionStatus.success, pt);
    } on DecryptionError {
      return const DecryptResult(EncryptionStatus.failure, null);
    }
  }

  Future<SignatureStatus> verify({required List<int> data, required List<int> signature, required EmailIdentity signer}) async {
    final ok = await engine.verify(data: data, signature: signature, signer: signer);
    return ok ? SignatureStatus.valid : SignatureStatus.invalid;
  }

  Future<List<int>> sign({required List<int> data, required EmailIdentity signer}) async {
    final key = await keyring.findByEmail(signer);
    if (key == null || !key.hasPrivate) {
      throw const KeyNotFoundError('Private key not found');
    }
    return engine.sign(data: data, keyId: key.id);
  }

  Future<List<int>> encrypt({required List<int> data, required List<EmailIdentity> recipients}) async {
    return engine.encrypt(data: data, recipients: recipients);
  }
}
