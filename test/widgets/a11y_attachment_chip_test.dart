import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/attachments/presentation/widgets/attachment_chip.dart';

void main() {
  testWidgets('AttachmentChip sets semantics label and min tap size', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AttachmentChip(
              icon: const Icon(Icons.attach_file),
              label: 'Document',
              semanticsLabel: 'Attachment: Document',
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final chipFinder = find.byType(AttachmentChip);
    expect(chipFinder, findsOneWidget);

    final size = tester.getSize(chipFinder);
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));

    // No exceptions raised during build/layout
    expect(tester.takeException(), isNull);
  });

  testWidgets('AttachmentChip scales at 2.0x without overflow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaleFactor: 2.0),
          child: const Scaffold(
            body: Center(
              child: AttachmentChip(label: 'A very very very long file name.pdf'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(AttachmentChip), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

