import '../entities/trust_policy.dart';
import '../value_objects/email_identity.dart';

abstract class TrustRepository {
  Future<TrustLevel> getTrustFor(EmailIdentity identity);
  Future<void> setTrustFor(EmailIdentity identity, TrustLevel level);
}
