import '../value_objects/key_id.dart';
import '../value_objects/fingerprint.dart';
import '../value_objects/email_identity.dart';

class KeyPair {
  final KeyId id;
  final Fingerprint fingerprint;
  final EmailIdentity owner;
  final bool hasPrivate;
  final DateTime createdAt;

  const KeyPair({
    required this.id,
    required this.fingerprint,
    required this.owner,
    required this.hasPrivate,
    required this.createdAt,
  });
}
