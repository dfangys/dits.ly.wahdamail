import '../value_objects/email_identity.dart';

enum TrustLevel { unknown, unverified, verified }

class TrustPolicy {
  final EmailIdentity identity;
  final TrustLevel level;
  const TrustPolicy({required this.identity, required this.level});
}
