import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/notifications/application/usecases/on_new_message.dart';
import 'package:wahda_bank/features/notifications/domain/events.dart';
import 'package:wahda_bank/features/settings/domain/settings_repository.dart';
import 'package:wahda_bank/features/settings/infrastructure/settings_store.dart';

void main() {
  test('NewMessageArrived maps to NotificationPayload with correct thread/group and quiet-hours silent', () async {
    final settings = FakeStorageSettings();
    // set quiet hours 22..7, and event at 23:00 => silent
    await settings.setQuietHours(const QuietHours(startHour: 22, endHour: 7));
    final uc = OnNewMessage(settings);

    final e = NewMessageArrived(
      accountId: 'acct',
      folderId: 'INBOX',
      threadKey: 't-1',
      messageId: 'm-1',
      from: 'Alice',
      subject: 'Hello',
      date: DateTime(2024, 1, 1, 23, 0, 0),
    );

    final p = await uc(e);
    expect(p.threadKey, 't-1');
    expect(p.groupKey, 'acct');
    expect(p.silent, true);
  });
}
