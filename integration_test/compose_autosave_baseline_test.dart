import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/models/sqlite_draft_repository.dart';
import 'package:wahda_bank/models/sqlite_mime_storage.dart';
import 'package:wahda_bank/services/feature_flags.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/features/messaging/presentation/controllers/compose_controller.dart';

class _LiteMailBoxController extends MailBoxController {
  @override
  void onInit() {
    super.onInit();
    // avoid heavy init in tests
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Compose autosave baseline', () {
    late MailAccount account;
    late Mailbox drafts;
    late SQLiteMailboxMimeStorage storage;
    late _LiteMailBoxController mbc;

    setUpAll(() async {
      WidgetsFlutterBinding.ensureInitialized();
      await GetStorage.init();

      // Speed up autosave to 1s for test
      await FeatureFlags.instance.setDraftAutosaveIntervalSecs(1);

      runApp(
        MaterialApp(builder: EasyLoading.init(), home: const SizedBox.shrink()),
      );

      if (!Get.isRegistered<SettingController>()) {
        Get.put(SettingController(), permanent: true);
      }
      if (!Get.isRegistered<SQLiteDraftRepository>()) {
        Get.put(SQLiteDraftRepository.instance, permanent: true);
        await SQLiteDraftRepository.instance.init();
      }

      // Minimal mail service
      final ms = MailService.instance;
      account = MailAccount.fromManualSettings(
        name: 'Test',
        email: 'test@example.com',
        incomingHost: 'localhost',
        outgoingHost: 'localhost',
        password: 'nopass',
        incomingType: ServerType.imap,
        outgoingType: ServerType.smtp,
      );
      ms.account = account;
      ms.client = MailClient(
        account,
        isLogEnabled: false,
        onBadCertificate: (_) => true,
      );

      drafts = Mailbox(
        encodedName: 'Drafts',
        encodedPath: 'Drafts',
        flags: [MailboxFlag.drafts],
        pathSeparator: '/',
      );
      drafts.name = 'Drafts';
      drafts.uidValidity = 7;

      storage = SQLiteMailboxMimeStorage(mailAccount: account, mailbox: drafts);
      await storage.init();

      mbc = _LiteMailBoxController();
      Get.put<MailBoxController>(mbc, permanent: true);
      mbc.mailboxes([drafts]);
      mbc.mailboxStorage[drafts] = storage;
      mbc.emails[drafts] = <MimeMessage>[];
      mbc.currentMailbox = drafts;
    });

    testWidgets(
      'autosave sets baseline; subsequent ticks do nothing when unchanged',
      (tester) async {
        final c = Get.put(ComposeController());
        c.sourceMailbox = drafts;
        c.isHtml.value = false;
        c.subjectController.text = 'Baseline';
        c.plainTextController.text = 'Hello';
        c.addTo(const MailAddress('', 'dest@example.com'));

        // Trigger change detection
        c.onContentChanged();

        // Wait > autosave interval for first save
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Inspect drafts stored
        final repo = SQLiteDraftRepository.instance;
        final all1 = await repo.getAllDrafts();
        expect(all1.length, greaterThanOrEqualTo(1));
        final d1 = all1.first;
        final t1 = d1.updatedAt;

        // No further edits - next autosave tick should be a no-op
        await tester.pumpAndSettle(const Duration(seconds: 2));

        final all2 = await repo.getAllDrafts();
        expect(all2.length, equals(all1.length));
        final d2 = all2.first;
        expect(
          d2.updatedAt.millisecondsSinceEpoch,
          equals(t1.millisecondsSinceEpoch),
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
