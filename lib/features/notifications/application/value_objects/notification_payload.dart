class NotificationPayload {
  final String title;
  final String body;
  final String threadKey;
  final String groupKey;
  final String deeplink;
  final String channelId;
  final bool silent;
  const NotificationPayload({
    required this.title,
    required this.body,
    required this.threadKey,
    required this.groupKey,
    required this.deeplink,
    this.channelId = 'inbox',
    this.silent = false,
  });
}
