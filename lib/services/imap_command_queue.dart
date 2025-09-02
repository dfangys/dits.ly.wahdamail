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

  // Idle coordination hooks (dependency-inverted to avoid import cycles)
  Future<void> Function()? _onPauseIdle;
  Future<void> Function()? _onResumeIdle;
  Duration _settleDelay = const Duration(milliseconds: 600);

  // Track in-flight commands to pause IDLE once per batch
  int _inFlight = 0;
  bool _idlePaused = false;
  Timer? _resumeTimer;

  /// Configure how the queue pauses/resumes IDLE around batches of commands.
  void configureIdleHooks({
    Future<void> Function()? onPause,
    Future<void> Function()? onResume,
    Duration? settleDelay,
  }) {
    _onPauseIdle = onPause;
    _onResumeIdle = onResume;
    if (settleDelay != null) _settleDelay = settleDelay;
  }

  Future<void> _pauseIdleOnce() async {
    if (_idlePaused) {
      // Cancel any pending resume when new work arrives
      _resumeTimer?.cancel();
      return;
    }
    _resumeTimer?.cancel();
    _idlePaused = true;
    try {
      if (_onPauseIdle != null) {
        await _onPauseIdle!();
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 IMAP queue: pause idle hook error: $e');
      }
    }
  }

  void _scheduleResumeIfQuiescent() {
    if (_inFlight > 0) return;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_settleDelay, () async {
      try {
        // Clear the paused flag BEFORE calling resume hook to avoid races where
        // the callee checks the paused state and aborts prematurely.
        _idlePaused = false;
        if (_onResumeIdle != null) {
          await _onResumeIdle!();
        }
      } catch (e) {
        if (kDebugMode) {
          print('📧 IMAP queue: resume idle hook error: $e');
        }
      }
    });
  }

  /// Enqueue [action] to run after previously enqueued actions complete.
  ///
  /// This ensures command-level serialization without blocking the UI thread.
  Future<T> run<T>(String label, Future<T> Function() action) {
    final completer = Completer<T>();

    // Chain onto the tail future
    _tail = _tail.then((_) async {
      _currentLabel = label;
      _inFlight += 1;
      try {
        await _pauseIdleOnce();
        final result = await action();
        if (!completer.isCompleted) completer.complete(result);
      } catch (e, st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      } finally {
        _currentLabel = null;
        _inFlight = (_inFlight - 1).clamp(0, 1 << 30);
        _scheduleResumeIfQuiescent();
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
        'inFlight': _inFlight,
        'idlePaused': _idlePaused,
        'settleDelayMs': _settleDelay.inMilliseconds,
      };
}

