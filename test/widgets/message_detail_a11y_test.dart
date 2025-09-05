import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Message detail a11y: app bar actions semantics + 44dp targets', (
    tester,
  ) async {
    bool starred = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            leading: Semantics(
              button: true,
              label: 'Back',
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                child: IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () {},
                ),
              ),
            ),
            title: const Text('Message'),
            actions: [
              Semantics(
                button: true,
                label: starred ? 'Unstar' : 'Star',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  child: IconButton(
                    tooltip: starred ? 'Unstar' : 'Star',
                    icon: Icon(
                      starred ? Icons.star_rounded : Icons.star_outline_rounded,
                    ),
                    onPressed: () {
                      starred = !starred;
                    },
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Reply',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  child: IconButton(
                    tooltip: 'Reply',
                    icon: const Icon(Icons.reply_rounded),
                    onPressed: () {},
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'More options',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  child: IconButton(
                    tooltip: 'More options',
                    icon: const Icon(Icons.more_vert_rounded),
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

    expect(find.bySemanticsLabel('Back'), findsOneWidget);
    expect(find.bySemanticsLabel('Star'), findsOneWidget);
    expect(find.bySemanticsLabel('Reply'), findsOneWidget);
    expect(find.bySemanticsLabel('More options'), findsOneWidget);

    expect(tester.getSize(find.byTooltip('Back')).width >= 44, isTrue);
    expect(tester.getSize(find.byTooltip('Back')).height >= 44, isTrue);
    expect(tester.getSize(find.byTooltip('Star')).width >= 44, isTrue);
    expect(tester.getSize(find.byTooltip('Star')).height >= 44, isTrue);
    expect(tester.getSize(find.byTooltip('Reply')).width >= 44, isTrue);
    expect(tester.getSize(find.byTooltip('Reply')).height >= 44, isTrue);
    expect(tester.getSize(find.byTooltip('More options')).width >= 44, isTrue);
    expect(tester.getSize(find.byTooltip('More options')).height >= 44, isTrue);
  });
}
