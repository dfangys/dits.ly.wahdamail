import 'package:injectable/injectable.dart';

/// Deterministic cohort membership using djb2 hash.
@lazySingleton
class CohortService {
  const CohortService();

  int djb2Hash(String s) {
    var h = 5381;
    for (final c in s.codeUnits) {
      h = ((h << 5) + h) + c; // h*33 + c
    }
    return h & 0x7fffffff;
  }

  bool inCohort(String email, int percent) => (djb2Hash(email) % 100) < percent;
}

