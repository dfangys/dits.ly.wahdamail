import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/observability/perf/compose_perf_sampler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ComposePerfSampler aggregates dropped_pct from synthetic frames', () {
    final sampler = ComposePerfSampler(opName: 'compose_editor_interaction');
    sampler.start();
    sampler.ingestSyntheticFrameDurations([
      10.0,
      12.0,
      22.0,
      30.0,
    ]); // 2 janky of 4
    final summary = sampler.buildSummary();
    expect(summary['op'], 'compose_editor_interaction');
    expect(summary['total_frames'], 4);
    expect(summary['jank_frames'], 2);
    final dropped = summary['dropped_pct'] as double;
    expect(dropped >= 49.9 && dropped <= 50.1, isTrue);
    sampler.stop();
  });
}
