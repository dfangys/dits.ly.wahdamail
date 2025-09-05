import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Compose a11y: semantics labels and 44dp min targets for key actions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              leading: Semantics(
                button: true,
                label: 'Back',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  child: IconButton(
                    tooltip: 'Back',
                    icon: const Icon(Icons.arrow_back_ios_rounded),
                    onPressed: () {},
                  ),
                ),
              ),
              title: const Text('Compose'),
              actions: [
                // Send
                Semantics(
                  button: true,
                  label: 'Send',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    child: IconButton(
                      tooltip: 'Send',
                      icon: const Icon(Icons.send_rounded),
                      onPressed: () {},
                    ),
                  ),
                ),
                // Attachment
                Semantics(
                  button: true,
                  label: 'Attach file',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    child: IconButton(
                      tooltip: 'Attach file',
                      icon: const Icon(Icons.attach_file_rounded),
                      onPressed: () {},
                    ),
                  ),
                ),
                // More
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
            body: const SizedBox.shrink(),
          ),
        ),
      );

      await tester.pump();

      expect(find.bySemanticsLabel('Back'), findsOneWidget);
      expect(find.bySemanticsLabel('Send'), findsOneWidget);
      expect(find.bySemanticsLabel('Attach file'), findsOneWidget);
      expect(find.bySemanticsLabel('More options'), findsOneWidget);

      expect(tester.getSize(find.byTooltip('Back')).width >= 44, isTrue);
      expect(tester.getSize(find.byTooltip('Back')).height >= 44, isTrue);
      expect(tester.getSize(find.byTooltip('Send')).width >= 44, isTrue);
      expect(tester.getSize(find.byTooltip('Send')).height >= 44, isTrue);
      expect(tester.getSize(find.byTooltip('Attach file')).width >= 44, isTrue);
      expect(
        tester.getSize(find.byTooltip('Attach file')).height >= 44,
        isTrue,
      );
      expect(
        tester.getSize(find.byTooltip('More options')).width >= 44,
        isTrue,
      );
      expect(
        tester.getSize(find.byTooltip('More options')).height >= 44,
        isTrue,
      );
    },
  );
}
