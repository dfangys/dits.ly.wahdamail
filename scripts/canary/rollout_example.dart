// scripts/canary/rollout_example.dart
// Helper script (no app code change). Demonstrates deterministic cohort selection using djb2 hash.
// Usage (conceptual): dart scripts/canary/rollout_example.dart alice@example.com 5

int djb2Hash(String s) {
  var h = 5381;
  for (final c in s.codeUnits) {
    h = ((h << 5) + h) + c; // h*33 + c
  }
  return h & 0x7fffffff;
}

bool inCohort(String email, int percent) => djb2Hash(email) % 100 < percent;

void main(List<String> args) {
  if (args.length < 2) {
    print('Usage: dart scripts/canary/rollout_example.dart <email> <percent>');
    return;
  }
  final email = args[0];
  final p = int.tryParse(args[1]) ?? 5;
  final h = djb2Hash(email);
  final cohort = inCohort(email, p);
  print('email=$email hash=$h cohortPercent=$p inCohort=$cohort');
}
