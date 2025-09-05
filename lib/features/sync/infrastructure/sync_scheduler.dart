/// Simple scheduler abstraction to start/stop sync in shadow mode (no WorkManager).
import 'package:wahda_bank/features/sync/infrastructure/sync_service.dart';

class SyncScheduler {
  final SyncService service;
  bool _running = false;

  SyncScheduler(this.service);

  Future<void> startShadow({
    required String accountId,
    required String folderId,
  }) async {
    if (_running) return;
    _running = true;
    await service.start(accountId: accountId, folderId: folderId);
  }

  Future<void> stop() async {
    if (!_running) return;
    _running = false;
    await service.stop();
  }
}
