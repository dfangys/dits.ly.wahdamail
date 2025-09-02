import '../../domain/services/encryption_service.dart';
import '../../domain/value_objects/signature_status.dart';
import '../../domain/value_objects/email_identity.dart';

class VerifySignature {
  final EncryptionService service;
  const VerifySignature(this.service);

  Future<SignatureStatus> call({required List<int> data, required List<int> signature, required EmailIdentity signer}) =>
      service.verify(data: data, signature: signature, signer: signer);
}
