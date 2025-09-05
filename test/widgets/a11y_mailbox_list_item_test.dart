import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/messaging/presentation/widgets/mailbox_list_item.dart';

void main() {
  testWidgets('MailboxListItem merges semantics and elides text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MailboxListItem(
            leading: const Icon(Icons.mail_outline),
            title: const Text(
              'A very very long subject line that should elide',
            ),
            subtitle: const Text(
              'A quite long subtitle to verify wrapping with ellipsis as needed',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.byType(MergeSemantics), findsOneWidget);
    expect(
      find.textContaining('A very very long subject line'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('MailboxListItem tolerates 2.0x text scale', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaleFactor: 2.0),
          child: const Scaffold(
            body: MailboxListItem(
              leading: Icon(Icons.mail_outline),
              title: Text('Subject'),
              subtitle: Text('Subtitle'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(MailboxListItem), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
