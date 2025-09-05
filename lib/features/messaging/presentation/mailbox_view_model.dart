import 'dart:async';
import 'dart:typed_data';
import 'package:injectable/injectable.dart';
// P12.3: inline prefetch (remove shim)
import 'package:wahda_bank/features/messaging/domain/repositories/message_repository.dart';
import 'package:wahda_bank/features/messaging/domain/entities/folder.dart'
    as dom;
import 'package:wahda_bank/features/messaging/domain/entities/message.dart'
    as dom_msg;
import 'package:wahda_bank/services/feature_flags.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';
import 'package:wahda_bank/shared/utils/hashing.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/services/attachment_fetcher.dart';
import 'package:wahda_bank/shared/di/injection.dart';

/// Presentation adapter for the mailbox feature.
///
/// Keeps orchestration out of UI controllers and respects P12 routing:
/// - Kill-switch supersedes feature flags
/// - Non-blocking prefetch via DDD when enabled (no UI change)
@lazySingleton
class MailboxViewModel {
  Future<void> prefetchOnMailboxOpen({
    required String folderId,
    String? requestId,
  }) async {
    if (FeatureFlags.instance.dddKillSwitchEnabled) return;
    if (!FeatureFlags.instance.dddMessagingEnabled) return;
    try {
      final repo = getIt<MessageRepository>();
      // Fire-and-forget prime (non-blocking)
      unawaited(
        repo
            .fetchInbox(
              folder: dom.Folder(id: folderId, name: folderId),
              limit: 10,
            )
            .catchError((_) => <dom_msg.Message>[]),
      );
    } catch (_) {}
  }

  void emitInboxOpenCompleted({
    required String requestId,
    required String folderId,
    required int latencyMs,
  }) {
    try {
      Telemetry.event(
        'inbox_open_ms',
        props: {
          'request_id': requestId,
          'op': 'inbox_open',
          'folder_id': folderId,
          'lat_ms': latencyMs,
          'mailbox_hash': Hashing.djb2(folderId).toString(),
        },
      );
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

  /// UI helper: ensure full message content is available (body/parts) before attachment operations.
  /// Delegates to AttachmentFetcher to avoid direct service imports in presentation.
  Future<MimeMessage> ensureFullMessage({
    required MimeMessage message,
    Mailbox? mailbox,
  }) async {
    try {
      final fetched = await AttachmentFetcher.ensureFullMessage(message);
      return fetched;
    } catch (_) {}
    return message;
  }

  /// UI helper: fetch attachment bytes for a given ContentInfo.
  /// Delegates to AttachmentFetcher for robust decoding and server fallback.
  Future<Uint8List?> fetchAttachmentBytes({
    required MimeMessage message,
    required ContentInfo content,
    Mailbox? mailbox,
  }) async {
    return await AttachmentFetcher.fetchBytes(
      message: message,
      content: content,
      mailbox: mailbox,
    );
  }
}
