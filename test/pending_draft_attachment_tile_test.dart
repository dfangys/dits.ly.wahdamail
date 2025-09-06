// ignore_for_file: must_call_super

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/utills/constants/language.dart';
import 'package:wahda_bank/features/messaging/presentation/screens/compose/widgets/pending_draft_attachment_tile.dart';
import 'package:wahda_bank/features/messaging/presentation/api/compose_controller_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PendingDraftAttachmentTile', () {
    testWidgets('shows localized View and Re-attach actions (EN)', (
      WidgetTester tester,
    ) async {
      // Register translations
      final translations = Lang();

      // Build widget with GetMaterialApp to enable .tr
      await tester.pumpWidget(
        GetMaterialApp(
          translations: translations,
          locale: const Locale('en'),
          home: Scaffold(
            body: PendingDraftAttachmentTile(
              meta: DraftAttachmentMeta(
                fetchId: '1',
                fileName: 'report.pdf',
                size: 1024 * 1024,
                mimeType: 'application/pdf',
              ),
              onReattach: () {},
              onView: () {},
            ),
          ),
        ),
      );

      // Verify localized labels
      expect(find.text('View'), findsOneWidget);
      expect(find.text('Re-attach'), findsOneWidget);
      expect(find.text('PDF'), findsOneWidget); // extension label
      expect(find.text('1.0 MB'), findsOneWidget); // formatted size
    });

    testWidgets('shows localized Arabic labels (AR)', (
      WidgetTester tester,
    ) async {
      final translations = Lang();

      await tester.pumpWidget(
        GetMaterialApp(
          translations: translations,
          locale: const Locale('ar'),
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: PendingDraftAttachmentTile(
                meta: DraftAttachmentMeta(
                  fetchId: '1',
                  fileName: 'image.jpg',
                  size: 2048,
                  mimeType: 'image/jpeg',
                ),
                onReattach: () {},
                onView: () {},
              ),
            ),
          ),
        ),
      );

      // The Arabic strings we added: 'view': 'عرض', 'reattach': 'إعادة إرفاق'
      expect(find.text('عرض'), findsOneWidget);
      expect(find.text('إعادة إرفاق'), findsOneWidget);
    });
  });
}
