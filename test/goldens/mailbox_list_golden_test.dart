import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/design_system/theme/app_theme.dart';
import 'package:wahda_bank/features/messaging/presentation/widgets/mailbox_list_item.dart';

Widget _mailboxListHarness(ThemeData theme) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: List.generate(3, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MailboxListItem(
              leading: const CircleAvatar(child: Text('A')),
              title: Text(
                'Subject line number ${i + 1} — A longer subject to test ellipsis',
              ),
              subtitle: const Text(
                'Preview body of the message goes here; it can be long and should ellipsize nicely.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          );
        }),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Mailbox list golden - light', (tester) async {
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    tester.binding.window.physicalSizeTestValue = const Size(800, 1200);

    await tester.pumpWidget(_mailboxListHarness(AppThemeDS.light));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/mailbox_list_light.png'),
    );
  });

  testWidgets('Mailbox list golden - dark', (tester) async {
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    tester.binding.window.physicalSizeTestValue = const Size(800, 1200);

    await tester.pumpWidget(_mailboxListHarness(AppThemeDS.dark));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/mailbox_list_dark.png'),
    );
  });

  testWidgets('Mailbox list golden - light @1.3x', (tester) async {
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    tester.binding.window.physicalSizeTestValue = const Size(800, 1200);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaleFactor: 1.3),
        child: _mailboxListHarness(AppThemeDS.light),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/mailbox_list_1_3x.png'),
    );
  });
}
