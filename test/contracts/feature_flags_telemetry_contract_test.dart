import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/services/feature_flags.dart';

void main() {
  group('Feature flags + telemetry baseline', () {
    test('telemetryPath defaults to legacy when DDD flags are off', () {
      // By default storage is empty; DDD flags should be false
      expect(FeatureFlags.telemetryPath, equals('legacy'));
    });
  });
}
