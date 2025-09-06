import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/features/messaging/presentation/api/compose_controller_api.dart';
import 'package:wahda_bank/app/api/mailbox_controller_api.dart';
// P12.3: inline DDD routing (remove shim)
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/draft_repository.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/outbox_repository.dart';
import 'package:wahda_bank/features/messaging/application/usecases/send_email.dart'
    as uc;
import 'package:wahda_bank/services/feature_flags.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';
import 'package:wahda_bank/shared/utils/hashing.dart';
import 'package:wahda_bank/shared/di/injection.dart';
import 'package:wahda_bank/shared/telemetry/tracing.dart';

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

    // Try DDD path first when eligible (inline use-case)
    if (!FeatureFlags.instance.dddKillSwitchEnabled &&
        FeatureFlags.instance.dddSendEnabled) {
      try {
        final span = Tracing.startSpan(
          'SendSmtp',
          attrs: {'request_id': requestId},
        );
        // Prepare SendEmail use-case
        final drafts = getIt<DraftRepository>();
        final outbox = getIt<OutboxRepository>();
        // Retrieve SMTP gateway without importing infra types; keep as Object to satisfy GetIt bounds.
        final smtp = getIt<Object>();
        final send = uc.SendEmail(
          drafts: drafts,
          outbox: outbox,
          smtp: smtp as dynamic,
        );

        // Gather inputs
        final accountId =
            (GetStorage().read('email') as String?) ?? 'default-account';
        final folderId =
            (controller.sourceMailbox != null &&
                    controller.sourceMailbox!.encodedPath.isNotEmpty)
                ? controller.sourceMailbox!.encodedPath
                : (controller.sourceMailbox?.name ?? 'INBOX');

        // Render raw RFC822 bytes
        List<int> rawBytes = const <int>[];
        String messageId = controller.composeSessionId;
        try {
          final any = (builtMessage as dynamic).renderMessage();
          if (any is List<int>) {
            rawBytes = any;
          } else if (any is String) {
            rawBytes = any.codeUnits;
          }
          final mid =
              builtMessage.getHeaderValue('message-id') ??
              builtMessage.getHeaderValue('Message-Id');
          if (mid != null && mid.trim().isNotEmpty) messageId = mid.trim();
        } catch (_) {}

        // Invoke use-case
        await send(
          accountId: accountId,
          folderId: folderId,
          draftId: controller.composeSessionId,
          messageId: messageId,
          rawBytes: rawBytes,
        );

        Tracing.end(span);
        // Telemetry success
        try {
          final acct = controller.email;
          Telemetry.event(
            'send_success',
            props: {
              'request_id': requestId,
              'op': 'send_email',
              'folder_id': folderId,
              'lat_ms': sw.elapsedMilliseconds,
              'account_id_hash': Hashing.djb2(acct).toString(),
            },
          );
        } catch (_) {}

        return true;
      } catch (e) {
        try {
          final acct = controller.email;
          final folderId =
              controller.sourceMailbox?.encodedPath ??
              controller.sourceMailbox?.name ??
              'INBOX';
          Telemetry.event(
            'send_failure',
            props: {
              'request_id': requestId,
              'op': 'send_email',
              'folder_id': folderId,
              'lat_ms': sw.elapsedMilliseconds,
              'error_class': e.runtimeType.toString(),
              'account_id_hash': Hashing.djb2(acct).toString(),
            },
          );
        } catch (_) {}
        // fall through to legacy
      }
    }

    // Legacy fallback
    bool ok = false;
    try {
      final boxController = Get.find<MailBoxController>();
      ok = await boxController.sendMailOptimistic(
        message: builtMessage,
        draftMessage: controller.msg,
        draftMailbox: controller.sourceMailbox,
      );
    } catch (_) {
      // In tests or headless contexts, MailBoxController may not be registered.
      ok = false;
    }

    // Operation telemetry: success/failure for legacy path
    try {
      final acct = controller.email;
      final folderId =
          controller.sourceMailbox?.encodedPath ??
          controller.sourceMailbox?.name ??
          'INBOX';
      if (ok) {
        Telemetry.event(
          'send_success',
          props: {
            'request_id': requestId,
            'op': 'send_email',
            'folder_id': folderId,
            'lat_ms': sw.elapsedMilliseconds,
            'account_id_hash': Hashing.djb2(acct).toString(),
          },
        );
      } else {
        Telemetry.event(
          'send_failure',
          props: {
            'request_id': requestId,
            'op': 'send_email',
            'folder_id': folderId,
            'lat_ms': sw.elapsedMilliseconds,
            'error_class': 'LegacySendFailed',
            'account_id_hash': Hashing.djb2(acct).toString(),
          },
        );
      }
    } catch (_) {}

    return ok;
  }
}
