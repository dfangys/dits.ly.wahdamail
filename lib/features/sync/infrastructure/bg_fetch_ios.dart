import 'dart:async';
import 'dart:io' show Platform;

import 'package:workmanager/workmanager.dart';

import 'package:wahda_bank/features/messaging/domain/repositories/message_repository.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/entities/folder.dart' as dom;
import 'package:wahda_bank/features/sync/infrastructure/circuit_breaker.dart';
import 'package:wahda_bank/features/sync/application/event_bus.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';

/// iOS background fetch fallback (P14): coalesced header refresh with circuit breaker.
class BgFetchIos {
  final dom.MessageRepository messages;
  final CircuitBreaker circuitBreaker;
  final SyncEventBus bus;
  final Duration coalesceWindow;
  final Future<bool> Function() _registerFn;

  bool _scheduled = false;
  Timer? _timer;
  int _pendingTicks = 0;

  BgFetchIos({
    required this.messages,
    required this.circuitBreaker,
    required this.bus,
    Duration? coalesceWindow,
    Future<bool> Function()? registerFn,
  })  : coalesceWindow = coalesceWindow ?? const Duration(seconds: 3),
        _registerFn = registerFn ?? _defaultRegister;

  static Future<bool> _defaultRegister() async {
    try {
      if (!Platform.isIOS) return false;
      // System-minimum; OS will throttle. Use a unique name; keep constraints to connected network.
      await Workmanager().registerPeriodicTask(
        'com.wahda_bank.ddd.iosBgFetch',
        'dddIosBgFetch',
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 5),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Idempotent start: schedules BG refresh on iOS and prepares in-app coalescing.
  Future<void> start() async {
    if (_scheduled) return;
    try {
      // Delegate platform checks to the register function; allows test injection.
      final ok = await _registerFn();
      _scheduled = ok;
    } catch (_) {}
  }

  /// Called by background driver or app lifecycle to signal a BG fetch opportunity.
  /// Multiple ticks within [coalesceWindow] coalesce into a single repo call.
  void tick({String folderId = 'INBOX'}) {
    // Metrics-only bus publish (Noop in P14)
    try {
      bus.publishBgFetchTick(folderId: folderId);
    } catch (_) {}

    _pendingTicks += 1;
    _timer?.cancel();
    _timer = Timer(coalesceWindow, () async {
      final sw = Stopwatch()..start();
      try {
        if (!circuitBreaker.allowExecution()) return;
        final list = await messages.fetchInbox(
          folder: dom.Folder(id: folderId, name: folderId),
          limit: 50,
          offset: 0,
        );
        circuitBreaker.recordSuccess();
        Telemetry.event('bg_fetch', props: {
          'op': 'bg_fetch',
          'ok': true,
          'folder_id': folderId,
          'fetched_count': list.length,
          'latency_ms': sw.elapsedMilliseconds,
          'coalesced': _pendingTicks,
        });
      } catch (e) {
        circuitBreaker.recordFailure();
        Telemetry.event('bg_fetch', props: {
          'op': 'bg_fetch',
          'ok': false,
          'folder_id': folderId,
          'latency_ms': sw.elapsedMilliseconds,
          'err_type': e.runtimeType.toString(),
          'coalesced': _pendingTicks,
        });
      } finally {
        _pendingTicks = 0;
      }
    });
  }
}

