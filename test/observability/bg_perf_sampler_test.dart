import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/observability/perf/bg_perf_sampler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('BgPerfSampler aggregates dropped_pct correctly', () {
    final sampler = BgPerfSampler(opName: 'idle_loop');
    sampler.start();
    // Two janky frames out of four => 50%
    sampler.ingestSyntheticFrameDurations([10.0, 30.0, 12.0, 25.0]);
    final summary = sampler.buildSummary();
    expect(summary['op'], 'idle_loop');
    expect(summary['total_frames'], 4);
    expect(summary['jank_frames'], 2);
    final dropped = summary['dropped_pct'] as double;
    expect(dropped >= 49.9 && dropped <= 50.1, isTrue);
    sampler.stop();
  });
}
