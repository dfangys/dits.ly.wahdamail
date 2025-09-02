import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:wahda_bank/shared/ddd_ui_wiring.dart';
import 'package:wahda_bank/services/feature_flags.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';
import 'package:wahda_bank/shared/utils/hashing.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';

/// Presentation adapter for the mailbox feature.
///
/// Keeps orchestration out of UI controllers and respects P12 routing:
/// - Kill-switch supersedes feature flags
/// - Non-blocking prefetch via DDD when enabled (no UI change)
@lazySingleton
class MailboxViewModel {
  Future<void> prefetchOnMailboxOpen({required String folderId, String? requestId}) async {
    if (FeatureFlags.instance.dddKillSwitchEnabled) return;
    // Delegate to centralized routing helper (same precedence as controllers)
    try {
      await DddUiWiring.maybeFetchInbox(folderId: folderId);
    } catch (_) {}
  }

  void emitInboxOpenCompleted({
    required String requestId,
    required String folderId,
    required int latencyMs,
  }) {
    try {
      Telemetry.event('inbox_open_ms', props: {
        'request_id': requestId,
        'op': 'inbox_open',
        'folder_id': folderId,
        'lat_ms': latencyMs,
        'mailbox_hash': Hashing.djb2(folderId).toString(),
      });
    } catch (_) {}
  }

  /// Delegate message open orchestration.
  /// For P12.1 there is no DDD handler for open; we preserve legacy behavior
  /// while centralizing the gating decision here.
  Future<void> openMessage({
    required MailBoxController controller,
    required Mailbox mailbox,
    required MimeMessage message,
    String? requestId,
  }) async {
    // Kill-switch > feature flag > default legacy
    try {
      if (!FeatureFlags.instance.dddKillSwitchEnabled &&
          FeatureFlags.instance.dddMessagingEnabled) {
        // No-op DDD branch for P12.1 — reserved for P12.2/12.3
        // Fall through to legacy open for now.
      }
    } catch (_) {}
    await controller.safeNavigateToMessageLegacy(message, mailbox);
  }
}

