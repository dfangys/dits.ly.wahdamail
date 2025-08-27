import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/services/background_service.dart';

/// Ensures Home-level heavy initialization runs only once per app session.
class HomeInitGuard extends GetxService {
  static HomeInitGuard get instance {
    if (!Get.isRegistered<HomeInitGuard>()) {
      Get.put(HomeInitGuard(), permanent: true);
    }
    return Get.find<HomeInitGuard>();
  }

  bool _didRun = false;

  /// Idempotent. Safe to call multiple times; executes once.
  Future<void> ensureInitialized(MailBoxController controller) async {
    if (_didRun) return;
    _didRun = true;

    if (kDebugMode) {
      debugPrint('🏠 HomeInitGuard: ensuring single initialization');
    }

    // Schedule derived fields backfill (safe to call repeatedly; fire-and-forget)
    try {
      BackgroundService.scheduleDerivedFieldsBackfill(
        perMailboxLimit: 5000,
        batchSize: 800,
      );
    } catch (_) {}

    // Ensure inbox is initialized if controller hasn't completed its own init yet.
    try {
      if (!controller.isInboxInitialized && !controller.isLoadingEmails.value) {
        await controller.initInbox();
      }
    } catch (_) {}
  }
}

