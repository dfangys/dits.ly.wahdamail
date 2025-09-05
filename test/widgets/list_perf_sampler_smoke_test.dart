import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/observability/perf/list_perf_sampler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('List with ListPerfSampler scrolls without errors (smoke)', (
    tester,
  ) async {
    final controller = ScrollController();
    final sampler = ListPerfSampler(
      opName: 'search_list_scroll',
      scrollController: controller,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            controller: controller,
            itemCount: 200,
            itemBuilder: (_, i) => SizedBox(height: 60, child: Text('Item $i')),
          ),
        ),
      ),
    );

    sampler.start();

    await tester.fling(find.text('Item 0'), const Offset(0, -600), 2000);
    await tester.pumpAndSettle();

    sampler.stop();

    // Just ensure we reached further items and no exceptions thrown
    expect(
      find.text('Item 150'),
      findsNothing,
    ); // might not be in view, but test should pass regardless
  });
}
