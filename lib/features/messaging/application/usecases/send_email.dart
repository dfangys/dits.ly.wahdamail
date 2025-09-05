import 'package:wahda_bank/features/messaging/domain/entities/draft.dart';
import 'package:wahda_bank/features/messaging/domain/entities/outbox_item.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/draft_repository.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/outbox_repository.dart';
import 'package:wahda_bank/features/messaging/domain/value_objects/retry_policy.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/smtp_gateway.dart';
import 'package:wahda_bank/shared/error/errors.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';

/// Use case: SendEmail (synchronous attempt only in P4)
class SendEmail {
  final DraftRepository drafts;
  final OutboxRepository outbox;
  final SmtpGateway smtp;
  final RetryPolicy retryPolicy;

  const SendEmail({
    required this.drafts,
    required this.outbox,
    required this.smtp,
    this.retryPolicy = const RetryPolicy(),
  });

  Future<OutboxItem> call({
    required String accountId,
    required String folderId,
    required String draftId,
    required String messageId,
    required List<int> rawBytes,
  }) async {
    // 1) Save/ensure draft
    final draft = Draft(
      id: draftId,
      accountId: accountId,
      folderId: folderId,
      messageId: messageId,
      rawBytes: rawBytes,
    );
    await drafts.saveDraft(draft);

    // 2) Enqueue
    final now = DateTime.now();
    final queued = await outbox.enqueue(
      OutboxItem(
        id: draftId,
        accountId: accountId,
        folderId: folderId,
        messageId: messageId,
        status: OutboxStatus.queued,
        createdAt: now,
        updatedAt: now,
      ),
    );

    // 3) Attempt synchronous send
    await outbox.markSending(queued.id);
    final sw = Stopwatch()..start();
    try {
      await smtp.send(accountId: accountId, rawBytes: rawBytes);
      await outbox.markSent(queued.id);
      return queued.copyWith(
        status: OutboxStatus.sent,
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      final err = e is AppError ? e : mapSmtpError(e);
      Telemetry.event(
        'operation',
        props: {
          'op': 'SendSmtp',
          'lat_ms': sw.elapsedMilliseconds,
          'error_class': err.runtimeType.toString(),
        },
      );
      final retryAt = retryPolicy.nextRetryAt(
        now: DateTime.now(),
        attemptCount: queued.attemptCount,
      );
      await outbox.markFailed(
        id: queued.id,
        errorClass: err.runtimeType.toString(),
        retryAt: retryAt,
      );
      return queued.copyWith(
        status: OutboxStatus.failed,
        lastErrorClass: err.runtimeType.toString(),
        retryAt: retryAt,
        updatedAt: DateTime.now(),
      );
    }
  }
}
