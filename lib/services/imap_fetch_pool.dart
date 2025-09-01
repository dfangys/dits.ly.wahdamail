import 'dart:async';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'mail_service.dart';

/// Dedicated lightweight IMAP client for short-lived fetches (envelope/full)
/// so we never interfere with the main client's IDLE/polling session.
class ImapFetchPool {
  ImapFetchPool._();
  static ImapFetchPool? _instance;
  static ImapFetchPool get instance => _instance ??= ImapFetchPool._();

  MailClient? _client; // single pooled client
  Future<void> _tail = Future.value();
  bool _connecting = false;

  MailAccount get _account => MailService.instance.account;

  Future<void> _ensureConnected() async {
    if (_client?.isConnected == true) return;
    if (_connecting) {
      // Chain until current connect completes
      await _tail; // ensures ordering
      if (_client?.isConnected == true) return;
    }
    _connecting = true;
    try {
      final cli = MailClient(
        _account,
        isLogEnabled: kDebugMode,
        onBadCertificate: (_) => true,
      );
      await cli.connect().timeout(const Duration(seconds: 20));
      _client = cli;
    } finally {
      _connecting = false;
    }
  }

  Future<Mailbox?> _resolveAndSelectMailbox(Mailbox mailboxHint) async {
    final cli = _client;
    if (cli == null || !cli.isConnected) return null;
    try {
      // If already selected equivalent mailbox, keep it
      final sel = cli.selectedMailbox;
      if (sel != null && _isSameMailbox(sel, mailboxHint)) {
        return sel;
      }
      // Find matching mailbox on this client
      final boxes = await cli.listMailboxes();
      Mailbox? match = boxes.firstWhereOrNull((mb) => _isSameMailbox(mb, mailboxHint));
      match ??= boxes.firstWhereOrNull((mb) => mb.isInbox && mailboxHint.isInbox);
      match ??= boxes.firstWhereOrNull((mb) => mb.name.toLowerCase() == mailboxHint.name.toLowerCase());
      match ??= boxes.firstWhereOrNull((mb) => mb.encodedPath.toLowerCase() == mailboxHint.encodedPath.toLowerCase());
      match ??= boxes.isNotEmpty ? boxes.first : null;
      if (match != null) {
        await cli.selectMailbox(match).timeout(const Duration(seconds: 10));
      }
      return cli.selectedMailbox;
    } catch (_) {
      return null;
    }
  }

  bool _isSameMailbox(Mailbox a, Mailbox b) {
    try {
      return a.encodedPath.toLowerCase() == b.encodedPath.toLowerCase() ||
          a.path.toLowerCase() == b.path.toLowerCase() ||
          a.name.toLowerCase() == b.name.toLowerCase() ||
          (a.isInbox && b.isInbox);
    } catch (_) {
      return false;
    }
  }

  /// Run an action on the pooled client serially to avoid overlapping commands.
  Future<T> _runSerial<T>(Future<T> Function(MailClient cli) action) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        await _ensureConnected();
        final cli = _client!;
        final result = await action(cli);
        if (!completer.isCompleted) completer.complete(result);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
        // If something went wrong, drop the client to force fresh connect next time
        try { _client?.disconnect(); } catch (_) {}
        _client = null;
      }
    });
    // Avoid unhandled errors on tail
    _tail.catchError((_) {});
    return completer.future;
  }

  Future<List<MimeMessage>> fetchForMessage({
    required MimeMessage base,
    required Mailbox mailboxHint,
    FetchPreference fetchPreference = FetchPreference.envelope,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    return _runSerial((cli) async {
      try {
        // Ensure proper mailbox selection on the pooled client
        await _resolveAndSelectMailbox(mailboxHint);
        final seq = MessageSequence.fromMessage(base);
        final fut = cli.fetchMessageSequence(
          seq,
          fetchPreference: fetchPreference,
        );
        final msgs = await fut.timeout(timeout, onTimeout: () => <MimeMessage>[]);
        return msgs;
      } catch (e) {
        if (kDebugMode) {
          print('📬 FetchPool fetchForMessage error: $e');
        }
        return <MimeMessage>[];
      }
    });
  }

  Future<List<MimeMessage>> fetchBySequence({
    required MessageSequence sequence,
    required Mailbox mailboxHint,
    FetchPreference fetchPreference = FetchPreference.envelope,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    return _runSerial((cli) async {
      try {
        await _resolveAndSelectMailbox(mailboxHint);
        final fut = cli.fetchMessageSequence(
          sequence,
          fetchPreference: fetchPreference,
        );
        final msgs = await fut.timeout(timeout, onTimeout: () => <MimeMessage>[]);
        return msgs;
      } catch (e) {
        if (kDebugMode) {
          print('📬 FetchPool fetchBySequence error: $e');
        }
        return <MimeMessage>[];
      }
    });
  }

  Future<List<MimeMessage>> fetchByUid({
    required int uid,
    required Mailbox mailboxHint,
    FetchPreference fetchPreference = FetchPreference.envelope,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    return _runSerial((cli) async {
      try {
        await _resolveAndSelectMailbox(mailboxHint);
        final fut = cli.fetchMessageSequence(
          MessageSequence.fromRange(uid, uid, isUidSequence: true),
          fetchPreference: fetchPreference,
        );
        final msgs = await fut.timeout(timeout, onTimeout: () => <MimeMessage>[]);
        return msgs;
      } catch (e) {
        if (kDebugMode) {
          print('📬 FetchPool fetchByUid error: $e');
        }
        return <MimeMessage>[];
      }
    });
  }

  /// Fetch the most recent [count] messages (envelope-only) from [mailboxHint].
  Future<List<MimeMessage>> fetchRecent({
    required Mailbox mailboxHint,
    int count = 20,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    return _runSerial((cli) async {
      try {
        final mb = await _resolveAndSelectMailbox(mailboxHint) ?? mailboxHint;
        final msgs = await cli
            .fetchMessages(mailbox: mb, count: count, page: 1)
            .timeout(timeout, onTimeout: () => <MimeMessage>[]);
        return msgs;
      } catch (e) {
        if (kDebugMode) {
          print('📬 FetchPool fetchRecent error: $e');
        }
        return <MimeMessage>[];
      }
    });
  }

  Future<void> dispose() async {
    try { _client?.disconnect(); } catch (_) {}
    _client = null;
  }
}


