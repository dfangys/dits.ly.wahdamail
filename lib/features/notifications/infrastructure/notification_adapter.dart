import 'dart:collection';

import 'package:wahda_bank/features/notifications/domain/ports/notification_port.dart';

class NoopNotificationAdapter implements NotificationPort {
  final List<String> log = [];

  @override
  Future<void> cancelByThread({required String threadKey}) async {
    log.add('cancel:$threadKey');
  }

  @override
  Future<void> showInboxSummary({
    required String accountId,
    required String groupKey,
    required String title,
    required String body,
    bool silent = false,
  }) async {
    log.add('summary:$groupKey:$title:$silent');
  }

  @override
  Future<void> showNewMessage({
    required String accountId,
    required String threadKey,
    required String title,
    required String body,
    required String deeplink,
    String channelId = 'inbox',
    bool silent = false,
  }) async {
    log.add('new:$threadKey:$title:$silent');
  }
}

class NotificationsCoordinator {
  final NoopNotificationAdapter port;
  final Set<String> _recentThreads = HashSet();
  bool _running = false;

  NotificationsCoordinator(this.port);

  void start() {
    // disabled until flag flip; call start() only in tests or when flag true
    _running = true;
  }

  void stop() {
    _running = false;
    _recentThreads.clear();
  }

  Future<void> onNew(
    String accountId,
    String threadKey,
    String title,
    String body, {
    required bool silent,
  }) async {
    if (!_running) return;
    if (_recentThreads.contains(threadKey)) return; // dedupe basic
    _recentThreads.add(threadKey);
    await port.showNewMessage(
      accountId: accountId,
      threadKey: threadKey,
      title: title,
      body: body,
      deeplink: '/thread/$threadKey',
      silent: silent,
    );
  }
}
