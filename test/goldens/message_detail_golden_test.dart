import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/design_system/theme/app_theme.dart';

Widget _messageDetailHarness(ThemeData theme, {double textScale = 1.0}) {
  final content = MaterialApp(
    theme: theme,
    home: Scaffold(
      appBar: AppBar(
        title: const Text('Message'),
        actions: const [Icon(Icons.more_vert_rounded), SizedBox(width: 8)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header card (subject + chips + sender row)
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quarterly results and strategy — Q3 wrap-up meeting notes',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, height: 1.2),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: -6,
                        children: const [
                          Chip(visualDensity: VisualDensity.compact, label: Text('3 in thread')),
                          Chip(visualDensity: VisualDensity.compact, label: Text('Attachments')),
                          Chip(visualDensity: VisualDensity.compact, label: Text('Flagged')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: const [
                          CircleAvatar(child: Text('AL', style: TextStyle(fontWeight: FontWeight.bold))),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Alice Longname',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                    Text(
                                      'Mon, Jan 1, 2025 at 9:41 AM',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.flag, size: 14),
                                    SizedBox(width: 4),
                                    Icon(Icons.attach_file, size: 14),
                                  ],
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'alice@example.com',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Body container card (placeholder only)
              Card(
                elevation: 0,
                child: SizedBox(
                  height: 320,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(width: 1),
                      ),
                      child: const Center(
                        child: Text('Body content container (placeholder)'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  if (textScale == 1.0) return content;
  return MediaQuery(
    data: MediaQueryData(textScaleFactor: textScale),
    child: content,
  );
}


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Message detail golden - light', (tester) async {
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    tester.binding.window.physicalSizeTestValue = const Size(800, 1200);

    await tester.pumpWidget(_messageDetailHarness(AppThemeDS.light));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/message_detail_light.png'),
    );
  });

  testWidgets('Message detail golden - dark', (tester) async {
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    tester.binding.window.physicalSizeTestValue = const Size(800, 1200);

    await tester.pumpWidget(_messageDetailHarness(AppThemeDS.dark));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/message_detail_dark.png'),
    );
  });

  testWidgets('Message detail golden - light @1.3x', (tester) async {
    tester.binding.window.devicePixelRatioTestValue = 1.0;
    tester.binding.window.physicalSizeTestValue = const Size(800, 1200);

    await tester.pumpWidget(_messageDetailHarness(AppThemeDS.light, textScale: 1.3));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/message_detail_1_3x.png'),
    );
  });
}

