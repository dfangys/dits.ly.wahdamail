import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/views/compose/models/draft_model.dart';
import 'package:wahda_bank/views/compose/redesigned_compose_screen.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';

// ignore_for_file: must_call_super

class TestSettingController extends SettingController {
  @override
  void onInit() {
    // Do not call super.onInit() to avoid GetStorage usage in tests
  }
}

class FakeComposeController extends ComposeController {
  @override
  void onInit() {
    // Skip heavy initialization (no settings/drafts hydration)
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();


  testWidgets('RedesignedComposeScreen displays draft subject, recipients, body, and attachments', (WidgetTester tester) async {
    // Create a temporary attachment file
    final tmpDir = await Directory.systemTemp.createTemp('compose_draft_test');
    final attachmentPath = p.join(tmpDir.path, 'report.pdf');
    final file = File(attachmentPath);
    await file.writeAsBytes(List.filled(32, 0x2E));

    // Build a plain-text draft (to avoid HtmlEditor platform dependencies in tests)
    final draft = DraftModel(
      subject: 'My Subject',
      body: 'This is the body content.',
      isHtml: false,
      to: ['Alice <alice@example.com>', 'bob@example.com'],
      cc: ['Carol <carol@example.com>'],
      bcc: ['dave@example.com'],
      attachmentPaths: [attachmentPath],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Inject a lightweight controller for the screen to reuse
    Get.put<ComposeController>(FakeComposeController());

    // Pump the screen
    await tester.pumpWidget(GetMaterialApp(
      home: RedesignedComposeScreen(draft: draft),
    ));

    // Allow post-frame callbacks to run and UI to settle
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Verify recipients are displayed
    expect(find.text('Alice'), findsOneWidget); // from "Alice <alice@...>"
    expect(find.text('bob@example.com'), findsOneWidget);
    expect(find.text('Carol'), findsOneWidget); // CC
    expect(find.text('dave@example.com'), findsOneWidget); // BCC

    // Verify attachments are displayed by file name
    expect(find.text('report.pdf'), findsOneWidget);

    // Verify subject and body values via controller backing the UI
    final controller = Get.find<ComposeController>();
    expect(controller.subjectController.text, equals('My Subject'));
    expect(controller.isHtml.value, isFalse);
    expect(controller.plainTextController.text, equals('This is the body content.'));

    // Verify plain text editor is visible
    expect(find.byKey(const ValueKey('plain_editor')), findsOneWidget);
  }, skip: true // Requires platform plugins (GetStorage/path_provider) not available in unit test environment
  );
}

