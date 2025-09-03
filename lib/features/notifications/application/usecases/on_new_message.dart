import 'package:wahda_bank/features/notifications/domain/events.dart';
import 'package:wahda_bank/features/notifications/application/value_objects/notification_payload.dart';
import 'package:wahda_bank/features/settings/domain/settings_repository.dart';

class OnNewMessage {
  final SettingsRepository settings;
  const OnNewMessage(this.settings);

  Future<NotificationPayload> call(NewMessageArrived e) async {
    final qh = await settings.getQuietHours();
    final now = e.date;
    final silent = _inQuietHours(now, qh.startHour, qh.endHour);
    final title = e.from;
    final body = e.subject;
    final threadKey = e.threadKey;
    final groupKey = e.accountId;
    final deeplink = '/inbox/${e.folderId}/${e.threadKey}/${e.messageId}';
    return NotificationPayload(
      title: title,
      body: body,
      threadKey: threadKey,
      groupKey: groupKey,
      deeplink: deeplink,
      silent: silent,
    );
  }

  bool _inQuietHours(DateTime now, int start, int end) {
    final h = now.hour;
    if (start == end) return false; // disabled
    if (start < end) {
      return h >= start && h < end;
    } else {
      // crosses midnight
      return h >= start || h < end;
    }
  }
}
