import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/observability/perf/message_detail_perf_sampler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MessageDetailPerfSampler aggregates dropped_pct from synthetic frames', () {
    final sampler = MessageDetailPerfSampler(opName: 'message_detail_render');
    sampler.start();
    sampler.ingestSyntheticFrameDurations([10.0, 25.0, 12.0, 20.0]); // 2/4 janky
    final summary = sampler.buildSummary();
    expect(summary['op'], 'message_detail_render');
    expect(summary['total_frames'], 4);
    expect(summary['jank_frames'], 2);
    final dropped = summary['dropped_pct'] as double;
    expect(dropped >= 49.9 && dropped <= 50.1, isTrue);
    sampler.stop();
  });
}

