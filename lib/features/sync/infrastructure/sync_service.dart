import 'dart:async';

import 'package:wahda_bank/features/messaging/domain/repositories/message_repository.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/entities/folder.dart' as dom;
import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';
import 'package:wahda_bank/features/sync/infrastructure/jitter_backoff.dart';
import 'package:wahda_bank/shared/error/errors.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';
import 'package:wahda_bank/observability/perf/bg_perf_sampler.dart';

/// Sync service (shadow mode): consumes ImapGateway.idleStream and triggers header fetches.
class SyncService {
  final ImapGateway gateway;
  final dom.MessageRepository messages;
  final JitterBackoff backoff;

  StreamSubscription<ImapEvent>? _sub;
  int _attempt = 0;
  Timer? _debounce;
  static const _window = Duration(milliseconds: 300);
  Stopwatch? _idleLoopSw;
  BgPerfSampler? _idleSampler;

  SyncService({required this.gateway, required this.messages, JitterBackoff? backoff})
      : backoff = backoff ?? JitterBackoff();

  Future<void> start({required String accountId, required String folderId}) async {
    await stop();
    _idleLoopSw = Stopwatch()..start();
    _idleSampler = BgPerfSampler(opName: 'idle_loop')..start();
    _sub = gateway
        .idleStream(accountId: accountId, folderId: folderId)
        .listen((event) async {
      // On events, trigger header-first fetch for that folder; shadow mode (no UI/notifications)
      if (event.type == ImapEventType.exists ||
          event.type == ImapEventType.expunge ||
          event.type == ImapEventType.flagsChanged) {
        // Coalesce burst events within a window
        _debounce?.cancel();
        _debounce = Timer(_window, () async {
          final _batchSampler = BgPerfSampler(opName: 'fetch_headers_batch')..start();
          try {
            await messages.fetchInbox(
              folder: dom.Folder(id: folderId, name: folderId),
              limit: 50,
              offset: 0,
            );
          } finally {
            _batchSampler.stop();
          }
        });
      }
    }, onError: (e, st) {
      // Classify and schedule retry with jitter
      final appErr = e is AppError ? e : mapImapError(e);
      final ms = _idleLoopSw?.elapsedMilliseconds ?? 0;
      try { _idleSampler?.stop(); } catch (_) {}
      try { _idleSampler?.stop(); } catch (_) {}
      Telemetry.event('operation', props: {
        'op': 'IdleLoop',
        'lat_ms': ms,
        'error_class': appErr.runtimeType.toString(),
      });
      _attempt += 1;
      final delay = backoff.forAttempt(_attempt);
      _scheduleRestart(accountId: accountId, folderId: folderId, delay: delay);
    }, onDone: () {
      final ms = _idleLoopSw?.elapsedMilliseconds ?? 0;
      Telemetry.event('operation', props: {
        'op': 'IdleLoop',
        'lat_ms': ms,
      });
      // Reconnect when stream closes
      _attempt += 1;
      final delay = backoff.forAttempt(_attempt);
      _scheduleRestart(accountId: accountId, folderId: folderId, delay: delay);
    });
  }

  void _scheduleRestart({required String accountId, required String folderId, required Duration delay}) {
    // Use a microtask timer to delay restart without tight loops.
    Future.delayed(delay, () {
      start(accountId: accountId, folderId: folderId);
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _attempt = 0;
  }
}

