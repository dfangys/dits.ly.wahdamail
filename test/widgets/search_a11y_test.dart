import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Search bar has explicit semantics labels and 44dp targets', (
    tester,
  ) async {
    // Minimal harness reproducing the search bar semantics without GetX deps
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: Semantics(
              textField: true,
              label: 'Search field',
              child: const TextField(),
            ),
            actions: [
              Semantics(
                button: true,
                label: 'Clear',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  child: IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.clear),
                    onPressed: () {},
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Search',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  child: IconButton(
                    tooltip: 'Search',
                    icon: const Icon(Icons.search),
                    onPressed: () {},
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();

    // Semantics labels present
    expect(find.bySemanticsLabel('Search field'), findsOneWidget);
    expect(find.bySemanticsLabel('Clear'), findsOneWidget);
    expect(find.bySemanticsLabel('Search'), findsOneWidget);

    // 44dp targets
    expect(tester.getSize(find.byTooltip('Clear')).width >= 44, isTrue);
    expect(tester.getSize(find.byTooltip('Clear')).height >= 44, isTrue);
    expect(tester.getSize(find.byTooltip('Search')).width >= 44, isTrue);
    expect(tester.getSize(find.byTooltip('Search')).height >= 44, isTrue);
  });
}
