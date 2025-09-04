import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/design_system/theme/app_theme.dart';
import 'package:wahda_bank/features/attachments/presentation/widgets/attachment_chip.dart';

Widget _attachmentsHarness(ThemeData theme, {double textScale = 1.0}) {
  final content = MaterialApp(
    theme: theme,
    home: Scaffold(
      appBar: AppBar(title: const Text('Attachments')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row mock (simple visual approximation)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.dividerColor),
              ),
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.picture_as_pdf, color: theme.colorScheme.primary),
                ),
                title: const Text('Quarterly_report_2025_Q2_very_long_name.pdf', maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('application/pdf • 1.2 MB', style: theme.textTheme.bodySmall),
                trailing: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download_rounded, size: 20),
                    SizedBox(width: 8),
                    Icon(Icons.share_rounded, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Chip
            const AttachmentChip(
              icon: Icon(Icons.attach_file, size: 16),
              label: 'diagram_final_v7.png',
            ),
          ],
        ),
      ),
    ),
  );
  if (textScale == 1.0) return content;
  return MediaQuery(data: MediaQueryData(textScaleFactor: textScale), child: content);
}


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Attachments golden - light', (tester) async {
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    tester.binding.window.physicalSizeTestValue = const Size(800, 1200);

    await tester.pumpWidget(_attachmentsHarness(AppThemeDS.light));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/attachments_light.png'),
    );
  });

  testWidgets('Attachments golden - dark', (tester) async {
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    tester.binding.window.physicalSizeTestValue = const Size(800, 1200);

    await tester.pumpWidget(_attachmentsHarness(AppThemeDS.dark));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/attachments_dark.png'),
    );
  });

  testWidgets('Attachments golden - light @1.3x', (tester) async {
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    tester.binding.window.physicalSizeTestValue = const Size(800, 1200);

    await tester.pumpWidget(_attachmentsHarness(AppThemeDS.light, textScale: 1.3));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/attachments_1_3x.png'),
    );
  });
}

