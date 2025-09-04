import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/attachments/presentation/widgets/attachment_chip.dart';
import 'package:wahda_bank/views/view/showmessage/widgets/attachment_viewer.dart';
import 'package:wahda_bank/design_system/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AttachmentChip exposes semantics and >=44dp tap target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeDS.light,
        home: Scaffold(
          body: Center(
            child: AttachmentChip(
              icon: const Icon(Icons.attach_file, size: 16),
              label: 'Attachment name really long to ellipsize',
              semanticsLabel: 'Open/Preview',
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final chip = find.byType(AttachmentChip);
    expect(chip, findsOneWidget);

    final semantics = tester.getSemantics(chip);
    expect((semantics.label ?? '').contains('Open/Preview'), isTrue);

    final size = tester.getSize(chip);
    expect(size.height >= 44, isTrue);
    expect(size.width >= 44, isTrue);
  });

  testWidgets('AttachmentViewer actions have semantics and >=44dp', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeDS.light,
        home: const AttachmentViewer(
          title: 'sample.txt',
          mimeType: 'text/plain',
          filePath: '/tmp/does_not_exist.txt',
          skipPreprocess: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Save button
    final save = find.byTooltip('Save');
    expect(save, findsOneWidget);
    final saveBox = tester.getSize(save);
    expect(saveBox.height >= 44, isTrue);
    expect(saveBox.width >= 44, isTrue);

    // Share button
    final share = find.byTooltip('Share');
    expect(share, findsOneWidget);
    final shareBox = tester.getSize(share);
    expect(shareBox.height >= 44, isTrue);
    expect(shareBox.width >= 44, isTrue);

    // Semantics labels on specific buttons (use semantics label finder for robustness)
    final saveLabelFinder = find.bySemanticsLabel(RegExp('save', caseSensitive: false));
    expect(saveLabelFinder, findsWidgets);

    final shareLabelFinder = find.bySemanticsLabel(RegExp('share', caseSensitive: false));
    expect(shareLabelFinder, findsWidgets);
  });
}

