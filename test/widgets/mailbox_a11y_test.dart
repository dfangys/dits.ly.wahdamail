import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Mailbox a11y: semantics labels and 44dp min targets for key actions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Mailbox'),
              actions: [
                Semantics(
                  button: true,
                  label: 'Refresh',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    child: IconButton(
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh_rounded),
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
            body: ListView(
              children: const [
                ListTile(title: Text('Message 1')),
                ListTile(title: Text('Message 2')),
              ],
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.bySemanticsLabel('Refresh'), findsOneWidget);
      expect(find.bySemanticsLabel('Search'), findsOneWidget);

      expect(tester.getSize(find.byTooltip('Refresh')).width >= 44, isTrue);
      expect(tester.getSize(find.byTooltip('Refresh')).height >= 44, isTrue);
      expect(tester.getSize(find.byTooltip('Search')).width >= 44, isTrue);
      expect(tester.getSize(find.byTooltip('Search')).height >= 44, isTrue);
    },
  );
}
