import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/observability/perf/compose_perf_sampler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Compose sampler smoke with PrimaryScrollController', (tester) async {
    final sampler1 = ComposePerfSampler(opName: 'compose_editor_interaction');
    final sampler2 = ComposePerfSampler(opName: 'compose_attachments_scroll');

    await tester.pumpWidget(MaterialApp(
      home: PrimaryScrollController(
        controller: ScrollController(),
        child: Scaffold(
          body: ListView.builder(
            itemCount: 100,
            itemBuilder: (_, i) => SizedBox(height: 48, child: Text('Row $i')),
          ),
        ),
      ),
    ));

    sampler1.start();
    sampler2.start();

    await tester.fling(find.text('Row 0'), const Offset(0, -800), 2000);
    await tester.pumpAndSettle();

    sampler1.stop();
    sampler2.stop();

    expect(find.text('Row 0'), findsNothing);
  });
}

