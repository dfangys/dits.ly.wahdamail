import 'dart:async';
import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/models/sqlite_draft_repository.dart';
import 'package:wahda_bank/views/compose/models/draft_model.dart';

/// Foreground scheduled-send service.
///
/// Periodically checks locally-scheduled drafts and sends them via SMTP
/// at or after their scheduled time. On success, removes the draft locally.
class ScheduledSendService {
  ScheduledSendService._();
  static final ScheduledSendService instance = ScheduledSendService._();

  Timer? _timer;
  bool _running = false;

  Future<void> init({Duration interval = const Duration(minutes: 1)}) async {
    // Idempotent init
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _tick());
    // Also run an immediate tick on init
    unawaited(_tick());
  }

  Future<void> dispose() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    if (_running) return;
    _running = true;
    try {
      await _processDueScheduledDrafts();
    } catch (e) {
      if (kDebugMode) {
        print('ScheduledSendService: tick error: $e');
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _processDueScheduledDrafts() async {
    final repo = SQLiteDraftRepository.instance;
    List<DraftModel> drafts = [];
    try {
      drafts = await repo.getScheduledDrafts();
    } catch (_) {}

    if (drafts.isEmpty) return;
    final now = DateTime.now();

    // Filter only those due to send
    final due =
        drafts
            .where(
              (d) => (d.scheduledFor != null && !d.scheduledFor!.isAfter(now)),
            )
            .toList();
    if (due.isEmpty) return;

    // Ensure MailBoxController exists
    if (!Get.isRegistered<MailBoxController>()) {
      try {
        Get.put(MailBoxController());
      } catch (_) {}
    }
    final mbc = Get.find<MailBoxController>();

    for (final draft in due) {
      try {
        final message = await _buildMessageFromDraft(draft);
        if (message == null) continue;

        final ok = await mbc.sendMailOptimistic(
          message: message,
          draftMessage: null,
          draftMailbox: null,
        );

        if (ok && draft.id != null) {
          // Remove the local scheduled draft on success
          await repo.deleteDraft(draft.id!);
        }
      } catch (e) {
        if (kDebugMode) {
          print('ScheduledSendService: failed to send draft ${draft.id}: $e');
        }
        // Keep draft for retry on next tick
      }
    }
  }

  Future<MimeMessage?> _buildMessageFromDraft(DraftModel draft) async {
    try {
      final builder = MessageBuilder();

      // Recipients
      builder.to = _parseAddresses(draft.to);
      builder.cc = _parseAddresses(draft.cc);
      builder.bcc = _parseAddresses(draft.bcc);

      // Subject
      builder.subject = draft.subject;

      // Content
      builder.addMultipartAlternative(
        htmlText: draft.isHtml ? draft.body : null,
        plainText: draft.isHtml ? _stripHtml(draft.body) : draft.body,
      );

      // From: use profile display name if available; else just the email address
      try {
        final mbc = Get.find<MailBoxController>();
        final acc = mbc.mailService.account;
        String senderName = '';
        try {
          if (Get.isRegistered<SettingController>()) {
            final sc = Get.find<SettingController>();
            senderName = sc.userName.value.trim();
          }
        } catch (_) {}
        if (senderName.isEmpty ||
            senderName.toLowerCase() == acc.email.toLowerCase()) {
          builder.from = [MailAddress('', acc.email)];
        } else {
          builder.from = [MailAddress(senderName, acc.email)];
        }
      } catch (_) {}

      // Read receipts
      try {
        if (Get.find<SettingController>().readReceipts()) {
          builder.requestReadReceipt();
        }
      } catch (_) {}

      // Attachments
      for (final path in draft.attachmentPaths) {
        try {
          final f = File(path);
          if (await f.exists()) {
            await builder.addFile(f, MediaType.guessFromFileName(path));
          }
        } catch (_) {}
      }

      final message = builder.buildMimeMessage();
      _normalizeTopLevelTransferEncoding(message);
      return message;
    } catch (e) {
      if (kDebugMode) {
        print('ScheduledSendService: build message error: $e');
      }
      return null;
    }
  }

  // Helpers
  List<MailAddress> _parseAddresses(List<String> addresses) {
    return addresses.map((addr) {
      final match = RegExp(r'(.*) <(.*)>').firstMatch(addr);
      if (match != null && match.group(1)!.isNotEmpty) {
        return MailAddress(match.group(1)!, match.group(2)!);
      } else {
        return MailAddress('', addr.replaceAll(RegExp(r'<|>'), ''));
      }
    }).toList();
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  void _normalizeTopLevelTransferEncoding(MimeMessage msg) {
    try {
      final ct =
          (msg.getHeaderValue('Content-Type') ??
                  msg.getHeaderValue('content-type') ??
                  '')
              .toLowerCase();
      if (ct.contains('multipart/')) {
        msg.setHeader('Content-Transfer-Encoding', '7bit');
      }
    } catch (_) {}
  }
}
