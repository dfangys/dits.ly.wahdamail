import 'package:injectable/injectable.dart';

import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/message_repository.dart' as dom;
import 'package:wahda_bank/features/sync/infrastructure/sync_service.dart';
import 'package:wahda_bank/features/sync/infrastructure/sync_scheduler.dart';
import 'package:wahda_bank/features/sync/application/event_bus.dart';

@module
abstract class SyncModule {
  @LazySingleton()
  SyncEventBus provideSyncEventBus() => NoopSyncEventBus();

  @LazySingleton()
  SyncService provideSyncService(ImapGateway gateway, dom.MessageRepository messages) =>
      SyncService(gateway: gateway, messages: messages);

  @LazySingleton()
  SyncScheduler provideSyncScheduler(SyncService service) => SyncScheduler(service);
}
