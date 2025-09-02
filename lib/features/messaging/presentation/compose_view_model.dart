import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/shared/ddd_ui_wiring.dart';
import 'package:wahda_bank/services/feature_flags.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';
import 'package:wahda_bank/shared/di/injection.dart';
import 'package:wahda_bank/shared/utils/hashing.dart';

/// Presentation adapter for compose/send orchestration.
/// - Respects P12 routing and kill-switch precedence
/// - Delegates to DDD via DddUiWiring when enabled
/// - Falls back to legacy optimistic send when DDD path is disabled
@lazySingleton
class ComposeViewModel {
  Future<bool> send({
    required ComposeController controller,
    required MimeMessage builtMessage,
    required String requestId,
  }) async {
    final sw = Stopwatch()..start();

    // Try DDD path first when eligible
    if (!FeatureFlags.instance.dddKillSwitchEnabled &&
        FeatureFlags.instance.dddSendEnabled) {
      final handled = await DddUiWiring.maybeSendFromCompose(
        controller: controller,
        builtMessage: builtMessage,
      );
      if (handled) {
        // Operation telemetry: success
        try {
          final acct = controller.account.email;
          final folderId =
              controller.sourceMailbox?.encodedPath ?? controller.sourceMailbox?.name ?? 'INBOX';
          Telemetry.event('send_success', props: {
            'request_id': requestId,
            'op': 'send_email',
            'folder_id': folderId,
            'lat_ms': sw.elapsedMilliseconds,
            'account_id_hash': Hashing.djb2(acct).toString(),
          });
        } catch (_) {}
        return true;
      }
    }

    // Legacy fallback
    final boxController = Get.find<MailBoxController>();
    final ok = await boxController.sendMailOptimistic(
      message: builtMessage,
      draftMessage: controller.msg,
      draftMailbox: controller.sourceMailbox,
    );

    // Operation telemetry: success/failure for legacy path
    try {
      final acct = controller.account.email;
      final folderId =
          controller.sourceMailbox?.encodedPath ?? controller.sourceMailbox?.name ?? 'INBOX';
      if (ok) {
        Telemetry.event('send_success', props: {
          'request_id': requestId,
          'op': 'send_email',
          'folder_id': folderId,
          'lat_ms': sw.elapsedMilliseconds,
          'account_id_hash': Hashing.djb2(acct).toString(),
        });
      } else {
        Telemetry.event('send_failure', props: {
          'request_id': requestId,
          'op': 'send_email',
          'folder_id': folderId,
          'lat_ms': sw.elapsedMilliseconds,
          'error_class': 'LegacySendFailed',
          'account_id_hash': Hashing.djb2(acct).toString(),
        });
      }
    } catch (_) {}

    return ok;
  }
}

