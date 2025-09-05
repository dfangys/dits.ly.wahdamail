import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/design_system/theme/tokens.dart';

Widget _searchBarHarness() {
  final controller = TextEditingController();
  return MaterialApp(
    home: FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: Scaffold(
        appBar: AppBar(
          title: Semantics(
            textField: true,
            label: 'Search field',
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'search',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: Tokens.space3,
                  horizontal: Tokens.space4,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      button: true,
                      label: 'Clear',
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                        child: IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            controller.clear();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: Tokens.space3),
                    Semantics(
                      button: true,
                      label: 'Search',
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
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
          ),
        ),
        body: ListView.builder(
          itemCount: 5,
          itemBuilder: (_, i) => ListTile(title: Text('Item $i')),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Search bar a11y: semantics and 44dp min tap targets', (tester) async {
    await tester.pumpWidget(_searchBarHarness());
    expect(find.bySemanticsLabel('Search field'), findsOneWidget);
    expect(find.bySemanticsLabel('Clear'), findsOneWidget);
    expect(find.bySemanticsLabel('Search'), findsOneWidget);

    final clearSize = tester.getSize(find.byTooltip('Clear'));
    final searchSize = tester.getSize(find.byTooltip('Search'));
    expect(clearSize.width >= 44 && clearSize.height >= 44, isTrue);
    expect(searchSize.width >= 44 && searchSize.height >= 44, isTrue);

    // Focus traversal group present
    expect(find.byType(FocusTraversalGroup), findsWidgets);
  });
}
