// scripts/canary/kill_switch_on.dart
// Helper script (no app code change). Documents flipping the kill switch and verifying via logs.
// This does not flip production flags; use this as guidance for internal QA/dev harness.

void main() {
  print('Kill switch procedure:');
  print(
    '1) Set ddd.kill_switch.enabled = true (persisted via your flag store)',
  );
  print('2) Restart the app/session');
  print(
    '3) Verify telemetry shows path=legacy for operations (e.g., inbox_open, search)',
  );
  print('4) Monitor error_class and lat_ms return to legacy baselines');
}
