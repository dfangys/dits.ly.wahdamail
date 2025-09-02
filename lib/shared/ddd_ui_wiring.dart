import 'dart:math' as math;
import 'dart:async' show unawaited;
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/services/feature_flags.dart';
import 'package:wahda_bank/shared/di/injection.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';

// DDD messaging domain + infra
import 'package:wahda_bank/features/messaging/domain/entities/folder.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/entities/message.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/repositories/message_repository.dart';
import 'package:wahda_bank/features/messaging/application/usecases/search_messages.dart' as uc;
import 'package:wahda_bank/features/messaging/domain/value_objects/search_query.dart' as dom;
import 'package:wahda_bank/features/messaging/application/usecases/send_email.dart' as uc;
import 'package:wahda_bank/features/messaging/domain/repositories/outbox_repository.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/draft_repository.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/smtp_gateway.dart';

// Legacy UI controllers and Enough Mail types
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';
import 'package:wahda_bank/widgets/search/controllers/mail_search_controller.dart';
import 'package:enough_mail/enough_mail.dart';

class DddUiWiring {
  static String _requestId() {
    final rnd = math.Random();
    return 'req-${DateTime.now().microsecondsSinceEpoch}-${rnd.nextInt(0x7fffffff)}';
  }

  // Public helper for controllers to annotate telemetry
  static String newRequestId() => _requestId();

  static bool _kill() => FeatureFlags.instance.dddKillSwitchEnabled;

  static Future<void> maybeFetchInbox({required String folderId}) async {
    try {
      if (_kill()) return;
      if (!FeatureFlags.instance.dddMessagingEnabled) return;
      final req = _requestId();
      Telemetry.event('ddd_route', props: {
        'op': 'FetchInbox',
        'req': req,
        'path': FeatureFlags.telemetryPath,
      });
      final repo = getIt<MessageRepository>();
      // Fire-and-forget prime (non-blocking)
      // Limit small window to keep it light; UI still uses legacy path for display.
      // Errors intentionally swallowed here.
      unawaited(
        repo
            .fetchInbox(folder: dom.Folder(id: folderId, name: folderId), limit: 10)
            .catchError((_) => <dom.Message>[]),
      );
    } catch (_) {}
  }

  // Route send flow to DDD use case when enabled. Returns true if handled (legacy should be skipped).
  static Future<bool> maybeSendFromCompose({
    required ComposeController controller,
    MimeMessage? builtMessage,
  }) async {
    try {
      if (_kill()) return false;
      if (!FeatureFlags.instance.dddSendEnabled) return false;

      // Prepare minimal inputs
      final req = _requestId();
      final box = GetStorage();
      final accountId = (box.read('email') as String?) ?? 'default-account';
      final folderId = controller.sourceMailbox?.encodedPath.isNotEmpty == true
          ? controller.sourceMailbox!.encodedPath
          : 'INBOX';

      // Render raw RFC822 bytes. If unavailable, fall back to empty bytes (EnoughSmtpGateway simulates success in P4).
      List<int> rawBytes = const <int>[];
      String messageId = controller.composeSessionId;
      try {
        final msg = builtMessage;
        if (msg != null) {
          final any = (msg as dynamic).renderMessage();
          if (any is List<int>) {
            rawBytes = any;
          } else if (any is String) {
            rawBytes = any.codeUnits;
          }
          final mid = msg.getHeaderValue('message-id') ?? msg.getHeaderValue('Message-Id');
          if (mid != null && mid.trim().isNotEmpty) messageId = mid.trim();
        }
      } catch (_) {}

      // Build use case from DI
      final drafts = getIt<DraftRepository>();
      final outbox = getIt<OutboxRepository>();
      final smtp = getIt<SmtpGateway>();
      final send = uc.SendEmail(drafts: drafts, outbox: outbox, smtp: smtp);

      Telemetry.event('ddd_route', props: {
        'op': 'SendEmail',
        'req': req,
        'path': FeatureFlags.telemetryPath,
      });

      final res = await send(
        accountId: accountId,
        folderId: folderId,
        draftId: controller.composeSessionId,
        messageId: messageId,
        rawBytes: rawBytes,
      );

      // Update UI similarly to legacy success
      try {
        controller.hasUnsavedChanges = false;
        controller.canPop.value = true;
        controller.update();
        // Best-effort UX: close composer
        Get.back();
      } catch (_) {}

      // Telemetry success marker (status field is internal to OutboxItem; report class only)
      Telemetry.event('ddd_send_enqueued', props: {
        'req': req,
        'status': res.status.toString(),
      });

      return true;
    } catch (e) {
      Telemetry.event('ddd_send_failed', props: {
        'error': e.runtimeType.toString(),
      });
      return false;
    }
  }

  // Route search to DDD when enabled. Returns true if handled.
  static Future<bool> maybeSearch({required MailSearchController controller}) async {
    try {
      if (_kill()) return false;
      if (!FeatureFlags.instance.dddSearchEnabled) return false;

      final req = _requestId();
      Telemetry.event('ddd_route', props: {
        'op': 'SearchMessages',
        'req': req,
        'path': FeatureFlags.telemetryPath,
      });

      final repo = getIt<MessageRepository>();
      final search = uc.SearchMessages(repo);
      final accountId = (GetStorage().read('email') as String?) ?? 'default-account';
      final query = dom.SearchQuery(text: controller.searchController.text, limit: 50);
      final results = await search(accountId: accountId, query: query);

      // Map domain results to minimal MimeMessage list for display (subject unknown in P6, use placeholder)
      final list = <MimeMessage>[];
      for (final r in results) {
        try {
          final mm = MimeMessage();
          final subj = 'Message';
          mm.envelope = Envelope(
            date: r.date,
            subject: subj,
            from: const [MailAddress('Unknown', 'unknown@unknown.com')],
          );
          list.add(mm);
        } catch (_) {}
      }

      controller.searchMessages = list;
      if (list.isEmpty) {
        controller.change(null, status: RxStatus.empty());
      } else {
        controller.change(list, status: RxStatus.success());
      }
      // Intentionally skip setting searchResults to ensure pagination is disabled in DDD path (P6 scope).
      return true;
    } catch (e) {
      Telemetry.event('ddd_search_failed', props: {
        'error': e.runtimeType.toString(),
      });
      return false;
    }
  }
}

