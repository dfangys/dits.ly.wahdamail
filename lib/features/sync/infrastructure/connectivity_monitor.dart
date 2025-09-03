import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:wahda_bank/features/messaging/domain/repositories/message_repository.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/entities/folder.dart' as dom;
import 'package:wahda_bank/features/sync/infrastructure/circuit_breaker.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';

/// Lightweight connectivity monitor (no deps beyond existing connectivity_plus).
/// On regain, reset circuit breaker and trigger one header refresh (debounced).
class ConnectivityMonitor {
  final dom.MessageRepository messages;
  final CircuitBreaker circuitBreaker;
  final Stream<List<ConnectivityResult>> _stream;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _debounce;

  ConnectivityMonitor({required this.messages, required this.circuitBreaker, Stream<List<ConnectivityResult>>? stream})
      : _stream = stream ?? Connectivity().onConnectivityChanged;

  Future<void> start({String folderId = 'INBOX'}) async {
    _sub = _stream.listen((results) {
      final online = !results.contains(ConnectivityResult.none);
      if (online) {
        // Debounce multiple quick transitions into a single refresh
        _debounce?.cancel();
        _debounce = Timer(const Duration(seconds: 2), () async {
          circuitBreaker.recordSuccess(); // reset CB
          final sw = Stopwatch()..start();
          try {
            final list = await messages.fetchInbox(
              folder: dom.Folder(id: folderId, name: folderId),
              limit: 50,
              offset: 0,
            );
            Telemetry.event('bg_fetch', props: {
              'op': 'bg_fetch',
              'ok': true,
              'folder_id': folderId,
              'fetched_count': list.length,
              'latency_ms': sw.elapsedMilliseconds,
            });
          } catch (e) {
            Telemetry.event('bg_fetch', props: {
              'op': 'bg_fetch',
              'ok': false,
              'folder_id': folderId,
              'latency_ms': sw.elapsedMilliseconds,
              'err_type': e.runtimeType.toString(),
            });
          }
        });
      }
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _debounce?.cancel();
    _debounce = null;
  }
}

