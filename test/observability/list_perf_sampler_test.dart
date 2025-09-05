import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:wahda_bank/observability/perf/list_perf_sampler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'ListPerfSampler aggregates dropped_pct and velocity percentiles',
    (tester) async {
      final controller = ScrollController();
      final sampler = ListPerfSampler(
        opName: 'mailbox_list_scroll',
        scrollController: controller,
      );

      sampler.start();
      // Inject synthetic frames: 2 janky (>16.7ms) out of 4 => 50%
      sampler.ingestSyntheticFrameDurations([10.0, 12.0, 18.0, 22.0]);
      // Inject velocities; median should be 250
      sampler.ingestVelocitySamples([100, 200, 250, 300]);

      final summary = sampler.buildSummary();
      expect(summary['op'], 'mailbox_list_scroll');
      expect(summary['total_frames'], 4);
      expect(summary['jank_frames'], 2);
      expect(
        (summary['dropped_pct'] as double) >= 49.9 &&
            (summary['dropped_pct'] as double) <= 50.1,
        isTrue,
      );
      expect(summary['scroll_velocity_px_s'], 250);

      // Check p95 helper roughly equals max for small sample
      sampler.ingestVelocitySamples([1000]);
      final p95 = sampler.percentileVelocity(95);
      expect(p95 >= 300 && p95 <= 1000, isTrue);

      sampler.stop();
    },
  );
}
