import '../domain/repositories/trust_repository.dart';
import '../domain/entities/trust_policy.dart';
import '../domain/value_objects/email_identity.dart';

class InMemoryTrustRepository implements TrustRepository {
  final Map<String, TrustLevel> _map = {};

  @override
  Future<TrustLevel> getTrustFor(EmailIdentity identity) async => _map[identity.email] ?? TrustLevel.unknown;

  @override
  Future<void> setTrustFor(EmailIdentity identity, TrustLevel level) async {
    _map[identity.email] = level;
  }
}
