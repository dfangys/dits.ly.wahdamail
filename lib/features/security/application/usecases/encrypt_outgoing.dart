import '../../domain/services/encryption_service.dart';
import '../../domain/value_objects/email_identity.dart';

class EncryptOutgoing {
  final EncryptionService service;
  const EncryptOutgoing(this.service);

  Future<List<int>> call({required List<int> data, required List<EmailIdentity> recipients}) =>
      service.encrypt(data: data, recipients: recipients);
}
