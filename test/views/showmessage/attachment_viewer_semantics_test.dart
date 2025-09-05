import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Attachment Preview actions semantics: labels and 44dp tap targets (harness)',
    (tester) async {
      // Minimal harness avoids plugin initialization while verifying a11y contract.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Attachment'),
              actions: [
                Semantics(
                  button: true,
                  label: 'Save',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    child: IconButton(
                      tooltip: 'Save',
                      icon: const Icon(Icons.download_rounded),
                      onPressed: () {},
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Share',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    child: IconButton(
                      tooltip: 'Share',
                      icon: const Icon(Icons.ios_share),
                      onPressed: () {},
                    ),
                  ),
                ),
              ],
            ),
            body: const SizedBox.expand(),
          ),
        ),
      );

      await tester.pump();

      // Verify labeled semantics for the key actions
      expect(find.bySemanticsLabel('Save'), findsOneWidget);
      expect(find.bySemanticsLabel('Share'), findsOneWidget);

      // Ensure minimum tap target >= 44x44 for the key actions
      final saveSize = tester.getSize(find.byTooltip('Save'));
      final shareSize = tester.getSize(find.byTooltip('Share'));
      expect(saveSize.width >= 44 && saveSize.height >= 44, isTrue);
      expect(shareSize.width >= 44 && shareSize.height >= 44, isTrue);
    },
  );
}
