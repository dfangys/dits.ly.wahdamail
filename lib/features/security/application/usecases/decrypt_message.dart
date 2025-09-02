import '../../domain/services/encryption_service.dart';
import '../../domain/value_objects/email_identity.dart';

class DecryptMessage {
  final EncryptionService service;
  const DecryptMessage(this.service);

  Future<DecryptResult> call({required List<int> ciphertext, required EmailIdentity recipient}) =>
      service.decrypt(ciphertext: ciphertext, recipient: recipient);
}
