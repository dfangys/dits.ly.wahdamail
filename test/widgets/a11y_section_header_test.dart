import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/messaging/presentation/widgets/section_header.dart';

void main() {
  testWidgets('SectionHeader exposes header semantics', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SectionHeader(title: 'Inbox'),
        ),
      ),
    );
    expect(find.text('Inbox'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SectionHeader handles large text-scale without overflow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaleFactor: 2.0),
          child: const Scaffold(
            body: SectionHeader(title: 'Very very long section title that should be elided'),
          ),
        ),
      ),
    );
    expect(find.byType(SectionHeader), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

