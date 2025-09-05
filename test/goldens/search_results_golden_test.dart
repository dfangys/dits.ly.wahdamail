import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/design_system/theme/app_theme.dart';
import 'package:wahda_bank/features/messaging/presentation/widgets/mailbox_list_item.dart';

Widget _searchResultsHarness(ThemeData theme) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemBuilder:
            (_, i) => MailboxListItem(
              leading: const Icon(Icons.mail_outline),
              title: Text(
                'Result ${i + 1} · Subject with long text to ellipsize properly',
              ),
              subtitle: const Text(
                'Short snippet of the result body for context...',
              ),
              trailing: const Icon(Icons.chevron_right),
            ),
        separatorBuilder: (_, __) => const Divider(),
        itemCount: 4,
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Search results golden - light', (tester) async {
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    tester.binding.window.physicalSizeTestValue = const Size(800, 1200);

    await tester.pumpWidget(_searchResultsHarness(AppThemeDS.light));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/search_results_light.png'),
    );
  });

  testWidgets('Search results golden - dark', (tester) async {
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    tester.binding.window.physicalSizeTestValue = const Size(800, 1200);

    await tester.pumpWidget(_searchResultsHarness(AppThemeDS.dark));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/search_results_dark.png'),
    );
  });

  testWidgets('Search results golden - light @1.3x', (tester) async {
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    tester.binding.window.physicalSizeTestValue = const Size(800, 1200);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaleFactor: 1.3),
        child: _searchResultsHarness(AppThemeDS.light),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/search_results_1_3x.png'),
    );
  });
}
