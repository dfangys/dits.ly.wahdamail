import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:wahda_bank/services/feature_flags.dart';
import 'package:wahda_bank/shared/flags/remote_flags.dart';
import 'package:wahda_bank/shared/flags/cohort_service.dart';
import 'package:wahda_bank/shared/telemetry/tracing.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';

const MethodChannel _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _pathProviderChannel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '/tmp';
    });
    await GetStorage.init();
    final getIt = GetIt.I;
    if (!getIt.isRegistered<RemoteFlags>()) {
      getIt.registerLazySingleton<RemoteFlags>(() => RemoteFlags());
    }
    if (!getIt.isRegistered<CohortService>()) {
      getIt.registerLazySingleton<CohortService>(() => const CohortService());
    }
  });

  tearDown(() async {
    await GetStorage().erase();
  });

  test('Remote flags precedence: kill-switch > remote > local', () async {
    final box = GetStorage();
    // Local defaults: all false
    await box.write('ddd.kill_switch.enabled', false);
    await box.write('ddd.search.enabled', false);

    // Remote override enables search
    await box.write('remote.flags.payload', {
      'ddd.search.enabled': true,
    });
    await GetIt.I<RemoteFlags>().load();

    // Without kill-switch, remote wins
    expect(FeatureFlags.instance.dddSearchEnabled, isTrue);

    // Kill-switch true should force false regardless of remote
    await box.write('ddd.kill_switch.enabled', true);
    expect(FeatureFlags.instance.dddKillSwitchEnabled, isTrue);
    expect(FeatureFlags.instance.dddSearchEnabled, isFalse);
  });

  test('CohortService membership deterministic', () {
    final svc = GetIt.I<CohortService>();
    final a = svc.inCohort('alice@example.com', 5);
    final b = svc.inCohort('alice@example.com', 5);
    expect(a, b);
  });

  test('Tracing spans no-op by default; can be enabled in tests and propagate request_id', () async {
    final events = <Map<String, Object?>>[];
    Telemetry.onEvent = (name, props) {
      if (name == 'span') events.add(props);
    };

    // Default off
    final s1 = Tracing.startSpan('TestSpan', attrs: {'request_id': 'req-1'});
    Tracing.end(s1);
    expect(events.isEmpty, isTrue);

    // Enable for tests
    Tracing.enableForTests(true);
    final s2 = Tracing.startSpan('TestSpan', attrs: {'request_id': 'req-2'});
    await Future<void>.delayed(const Duration(milliseconds: 1));
    Tracing.end(s2);

    expect(events.isNotEmpty, isTrue);
    expect(events.last['span'], 'TestSpan');
    expect(events.last['request_id'], 'req-2');

    // Reset
    Tracing.enableForTests(false);
    Telemetry.onEvent = null;
  });
}

