import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/models/sqlite_mime_storage.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/services/imap_fetch_pool.dart';

/// Background preview generation service with a bounded queue.
///
/// - Generates previews for messages missing preview_text
/// - Uses current selected mailbox only to avoid IMAP selection thrash
/// - Offloads HTML normalization via compute()
class PreviewService extends GetxService {
  static PreviewService get instance {
    if (!Get.isRegistered<PreviewService>()) {
      Get.put(PreviewService(), permanent: true);
    }
    return Get.find<PreviewService>();
  }

  final int maxConcurrent =
      4; // Slightly higher concurrency for faster first-run previews
  int _active = 0;

  final Queue<_PreviewJob> _queue = Queue<_PreviewJob>();
  final Set<String> _canceledKeys = <String>{};

  void cancelForMailbox(Mailbox mailbox) {
    _canceledKeys.add(_mbKey(mailbox));
  }

  void clearCancelation(Mailbox mailbox) {
    _canceledKeys.remove(_mbKey(mailbox));
  }

  String _mbKey(Mailbox mailbox) => mailbox.encodedPath;
  String _jobKey(Mailbox m, MimeMessage msg) =>
      '${_mbKey(m)}:${msg.uid ?? msg.sequenceId ?? "0"}';

  /// Queue a batch of messages for preview backfill (first N missing)
  void queueBackfillForMessages({
    required Mailbox mailbox,
    required List<MimeMessage> messages,
    required SQLiteMailboxMimeStorage storage,
    int maxJobs = 50,
  }) {
    clearCancelation(mailbox);
    int queued = 0;
    for (final msg in messages) {
      if (queued >= maxJobs) break;
      final hasPreview =
          (msg.getHeaderValue('x-preview') ?? '').trim().isNotEmpty;
      if (hasPreview) continue;
      _queueJob(mailbox, msg, storage);
      queued++;
    }
    _pump();
  }

  void _queueJob(
    Mailbox mailbox,
    MimeMessage message,
    SQLiteMailboxMimeStorage storage,
  ) {
    final key = _jobKey(mailbox, message);
    // Avoid duplicates
    if (_queue.any((j) => j.key == key)) return;

    _queue.add(
      _PreviewJob(
        key: key,
        mailbox: mailbox,
        messageRef: message,
        storage: storage,
      ),
    );
  }

  void _pump() {
    while (_active < maxConcurrent && _queue.isNotEmpty) {
      final job = _queue.removeFirst();
      _run(job);
    }
  }

  Future<void> _run(_PreviewJob job) async {
    _active++;
    try {
      // If mailbox switched away and canceled, skip
      if (_canceledKeys.contains(_mbKey(job.mailbox))) return;

      final mailService = MailService.instance;

      // Only run if the selected mailbox matches to avoid selection thrash
      final selected = mailService.client.selectedMailbox;
      if (selected == null || selected.encodedPath != job.mailbox.encodedPath) {
        return; // Skip silently
      }

      // Fetch full message from server for preview if needed
      MimeMessage? full;
      try {
        // Use the dedicated fetch pool to avoid interfering with IDLE/polling
        final fetched = await ImapFetchPool.instance.fetchForMessage(
          base: job.messageRef,
          mailboxHint: job.mailbox,
          fetchPreference: FetchPreference.fullWhenWithinSize,
          timeout: const Duration(seconds: 10),
        );
        if (fetched.isEmpty) return;
        full = fetched.first;
      } catch (e) {
        if (kDebugMode) {
          print('🧵 Preview backfill fetch failed: $e');
        }
        return;
      }

      // Generate preview (prefer plain text; else strip HTML off-thread)
      String preview = '';
      try {
        final plain = full.decodeTextPlainPart();
        if (plain != null && plain.isNotEmpty) {
          preview = await compute(_normalizePreviewSync, plain);
        } else {
          final html = full.decodeTextHtmlPart();
          if (html != null && html.isNotEmpty) {
            preview = await compute(_stripAndNormalize, html);
          }
        }
      } catch (_) {}

      final hasAttachments = () {
        try {
          return full?.hasAttachments() ?? false;
        } catch (_) {
          return false;
        }
      }();

      if (preview.isEmpty && hasAttachments) {
        preview = '📎 Message with attachments';
      }

      // Persist preview + attachments to DB
      try {
        await job.storage.updatePreviewAndAttachments(
          uid: full.uid,
          sequenceId: full.sequenceId,
          previewText: preview,
          hasAttachments: hasAttachments,
        );
      } catch (e) {
        if (kDebugMode) {
          print('🧵 Preview persistence failed: $e');
        }
      }

      // Stamp headers on the in-memory message to benefit current session
      try {
        job.messageRef.setHeader('x-preview', preview);
        job.messageRef.setHeader(
          'x-has-attachments',
          hasAttachments ? '1' : '0',
        );
        job.messageRef.setHeader('x-ready', '1');
      } catch (_) {}

      // Notify UI (per-message meta tick)
      try {
        if (Get.isRegistered<MailBoxController>()) {
          Get.find<MailBoxController>().bumpMessageMeta(
            job.mailbox,
            job.messageRef,
          );
        }
      } catch (_) {}
    } finally {
      _active--;
      _pump();
    }
  }
}

class _PreviewJob {
  final String key;
  final Mailbox mailbox;
  final MimeMessage messageRef;
  final SQLiteMailboxMimeStorage storage;
  _PreviewJob({
    required this.key,
    required this.mailbox,
    required this.messageRef,
    required this.storage,
  });
}

// Pure function for compute()
String _stripAndNormalize(String html) {
  final stripped = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
  return _normalizePreviewSync(stripped);
}

String _normalizePreviewSync(String input) {
  final oneLine = input.replaceAll(RegExp(r'\s+'), ' ').trim();
  return oneLine.length > 140 ? oneLine.substring(0, 140) : oneLine;
}
