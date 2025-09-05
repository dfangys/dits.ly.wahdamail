import '../../domain/services/encryption_service.dart';
import '../../domain/value_objects/email_identity.dart';

class SignOutgoing {
  final EncryptionService service;
  const SignOutgoing(this.service);

  Future<List<int>> call({
    required List<int> data,
    required EmailIdentity signer,
  }) => service.sign(data: data, signer: signer);
}
