abstract class NotificationPort {
  Future<void> showInboxSummary({required String accountId, required String groupKey, required String title, required String body, bool silent = false});
  Future<void> showNewMessage({required String accountId, required String threadKey, required String title, required String body, required String deeplink, String channelId = 'inbox', bool silent = false});
  Future<void> cancelByThread({required String threadKey});
}
