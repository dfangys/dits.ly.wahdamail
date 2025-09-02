import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/notifications/infrastructure/notification_adapter.dart';

void main() {
  test('Coordinator routes new message and dedupes by thread', () async {
    final port = NoopNotificationAdapter();
    final coord = NotificationsCoordinator(port);
    coord.start(); // enabled in test

    await coord.onNew('acct', 'thread-1', 'Alice', 'Hi', silent: false);
    await coord.onNew('acct', 'thread-1', 'Alice', 'Hi again', silent: false);

    // only one new:thread-1 entry
    final lines = port.log.where((l) => l.startsWith('new:thread-1')).toList();
    expect(lines.length, 1);
  });
}
