import 'dart:async';
import 'package:flutter/foundation.dart';

/// A simple FIFO queue to serialize IMAP client operations across the app.
///
/// enough_mail can juggle IDLE and commands, but concurrent calls from many
/// places (controllers, services, previews) can interleave and cause protocol
/// contention (e.g., overlapping IDLE/DONE, continuation not handled).
///
/// Use this queue to ensure only one outbound IMAP command runs at a time for
/// operations we initiate from the app (select, fetch, mark, etc.). DO NOT wrap
/// long-lived operations like startPolling/IDLE inside this queue, as they would
/// block other operations. Only wrap discrete commands.
class ImapCommandQueue {
  ImapCommandQueue._();
  static ImapCommandQueue? _instance;
  static ImapCommandQueue get instance => _instance ??= ImapCommandQueue._();

  // The last scheduled future in the chain
  Future<void> _tail = Future.value();

  // Optional debug label of the currently running task
  String? _currentLabel;

  /// Enqueue [action] to run after previously enqueued actions complete.
  ///
  /// This ensures command-level serialization without blocking the UI thread.
  Future<T> run<T>(String label, Future<T> Function() action) {
    final completer = Completer<T>();

    // Chain onto the tail future
    _tail = _tail.then((_) async {
      _currentLabel = label;
      try {
        final result = await action();
        if (!completer.isCompleted) completer.complete(result);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      } finally {
        _currentLabel = null;
      }
    });

    // Ensure errors on the tail are observed to avoid unhandled exceptions
    _tail.catchError((e) {
      if (kDebugMode) {
        // Swallow but log
        print('📧 IMAP queue tail error (ignored): $e');
      }
    });

    return completer.future;
  }

  /// Returns a debug snapshot of the queue state.
  Map<String, dynamic> debugState() => {
        'hasPending': _currentLabel != null,
        'currentLabel': _currentLabel,
      };
}

