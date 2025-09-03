import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/design_system/theme/app_theme.dart';

Widget _composeShellHarness(ThemeData theme) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      appBar: AppBar(
        title: const Text('Compose'),
        actions: const [Icon(Icons.send_rounded), SizedBox(width: 8)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('To', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text('Subject', style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 16),
            Text('Body preview area...'),
          ],
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Compose shell golden - light', (tester) async {
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    tester.binding.window.physicalSizeTestValue = const Size(800, 1200);

    await tester.pumpWidget(_composeShellHarness(AppThemeDS.light));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/compose_shell_light.png'),
    );
  });
}

