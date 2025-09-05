import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/observability/perf/message_detail_perf_sampler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Message detail smoke: render + scroll samplers attach', (
    tester,
  ) async {
    final renderSampler = MessageDetailPerfSampler(
      opName: 'message_detail_render',
    );
    final scrollSampler = MessageDetailPerfSampler(
      opName: 'message_detail_body_scroll',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PrimaryScrollController(
          controller: ScrollController(),
          child: Scaffold(
            appBar: AppBar(title: const Text('Message')),
            body: SingleChildScrollView(
              child: Column(
                children: List.generate(
                  100,
                  (i) => SizedBox(height: 40, child: Text('L$i')),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    renderSampler.start();
    scrollSampler.start();

    await tester.fling(find.text('L0'), const Offset(0, -800), 1500);
    await tester.pumpAndSettle();

    renderSampler.stop();
    scrollSampler.stop();
  });
}
