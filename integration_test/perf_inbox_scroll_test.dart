import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wahda_bank/perf/perf_inbox_demo.dart';
import 'package:wahda_bank/utils/perf/perf_tracer.dart';

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Perf: open inbox demo and long continuous scroll',
    (tester) async {
      // Pump the demo inbox directly to avoid auth/network variability.
      await tester.pumpWidget(const MaterialApp(home: PerfInboxDemo()));

      // Wait for first frame/content (skeleton time proxy)
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      final scrollFinder = find.byKey(const Key('perf_inbox_scroll'));
      expect(scrollFinder, findsOneWidget);

      // Record frame timings during long scroll.
      final sampler = FrameTimingSampler();
      sampler.reset();
      sampler.attach();

      // Mixed-speed long scroll over ~1,500+ items using flings and drags.
      final controller = PrimaryScrollController.of(
        tester.element(scrollFinder),
      );
      for (int i = 0; i < 20; i++) {
        await tester.fling(scrollFinder, const Offset(0, -600), 2000);
        await tester.pump(const Duration(milliseconds: 16));
      }
      for (int i = 0; i < 10; i++) {
        await tester.fling(scrollFinder, const Offset(0, -400), 1200);
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Gentle drags to simulate mixed speeds.
      for (int i = 0; i < 40; i++) {
        await tester.drag(scrollFinder, const Offset(0, -200));
        await tester.pump(const Duration(milliseconds: 16));
      }

      // Small pause to settle after scroll.
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Use controller to ensure we scrolled.
      expect(controller.hasClients, true);

      // Stop sampling and summarize.
      sampler.detach();
      final summary = sampler.summarize();

      // Read perf config thresholds if present
      double frameBudgetMs = 16.0;
      double p95JankyPctMax = 1.0;
      try {
        final file = File('perf/perf_config.json');
        if (file.existsSync()) {
          final cfg =
              json.decode(file.readAsStringSync()) as Map<String, dynamic>;
          frameBudgetMs =
              (cfg['frame_budget_ms'] as num?)?.toDouble() ?? frameBudgetMs;
          p95JankyPctMax =
              (cfg['p95_janky_frames_pct_max'] as num?)?.toDouble() ??
              p95JankyPctMax;
        }
      } catch (_) {}

      // Report in integration test binding so CI can collect it.
      binding.reportData = <String, dynamic>{
        'frameTiming': summary,
        'config': {
          'frame_budget_ms': frameBudgetMs,
          'p95_janky_frames_pct_max': p95JankyPctMax,
        },
      };

      // Enforce gating based on config
      final avgTotal = (summary['avg_total_ms'] as num).toDouble();
      final p95Total = (summary['p95_total_ms'] as num).toDouble();
      final jankyPct = (summary['janky_pct'] as num).toDouble();

      expect(avgTotal, lessThanOrEqualTo(frameBudgetMs));
      // Allow p95 to be higher than avg budget but still close; 1.4x factor is a pragmatic bound
      expect(p95Total, lessThanOrEqualTo(frameBudgetMs * 1.4));
      expect(jankyPct, lessThanOrEqualTo(p95JankyPctMax));
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
