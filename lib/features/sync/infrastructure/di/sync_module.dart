import 'package:injectable/injectable.dart';

import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/message_repository.dart' as dom;
import 'package:wahda_bank/features/sync/infrastructure/sync_service.dart';
import 'package:wahda_bank/features/sync/infrastructure/sync_scheduler.dart';
import 'package:wahda_bank/features/sync/application/event_bus.dart';
import 'package:wahda_bank/features/sync/infrastructure/jitter_backoff.dart';
import 'package:wahda_bank/features/sync/infrastructure/circuit_breaker.dart';
import 'package:wahda_bank/features/sync/infrastructure/bg_fetch_ios.dart';
import 'package:wahda_bank/features/sync/infrastructure/connectivity_monitor.dart';

@module
abstract class SyncModule {
  @LazySingleton()
SyncEventBus provideSyncEventBus() => NoopSyncEventBus();

  @LazySingleton()
  CircuitBreaker provideCircuitBreaker() => CircuitBreaker();

  @LazySingleton()
  SyncService provideSyncService(ImapGateway gateway, dom.MessageRepository messages) =>
      SyncService(
        gateway: gateway,
        messages: messages,
        backoff: JitterBackoff(
          baseSchedule: const [
            Duration(seconds: 2),
            Duration(seconds: 4),
            Duration(seconds: 8),
            Duration(seconds: 16),
            Duration(seconds: 32),
            Duration(seconds: 64),
            Duration(seconds: 120),
          ],
          maxBackoff: const Duration(seconds: 120),
          jitter: 0.2,
        ),
      );

  @LazySingleton()
  SyncScheduler provideSyncScheduler(SyncService service) => SyncScheduler(service);

  @LazySingleton()
  BgFetchIos provideBgFetchIos(dom.MessageRepository messages, CircuitBreaker cb, SyncEventBus bus) =>
      BgFetchIos(messages: messages, circuitBreaker: cb, bus: bus);

  @LazySingleton()
  ConnectivityMonitor provideConnectivityMonitor(dom.MessageRepository messages, CircuitBreaker cb) =>
      ConnectivityMonitor(messages: messages, circuitBreaker: cb);
}
