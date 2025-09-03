import 'package:wahda_bank/features/notifications/domain/events.dart';
import 'package:wahda_bank/features/notifications/application/value_objects/notification_payload.dart';

class OnSyncFailed {
  const OnSyncFailed();
  NotificationPayload call(SyncFailed e) => NotificationPayload(
        title: 'Sync failed',
        body: e.reason,
        threadKey: 'sync:${e.accountId}:${e.folderId}',
        groupKey: e.accountId,
        deeplink: '/sync/${e.accountId}/${e.folderId}',
        channelId: 'sync',
        silent: false,
      );
}
