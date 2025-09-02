import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/settings/domain/settings_repository.dart';
import 'package:wahda_bank/features/settings/infrastructure/settings_store.dart';

void main() {
  test('Settings defaults and set/get and migration keys behave', () async {
    final repo = FakeStorageSettings();

    // defaults
    var qh = await repo.getQuietHours();
    expect(qh.startHour, 22);
    expect(qh.endHour, 7);
    expect(await repo.getSoundEnabled(), true);
    expect(await repo.getVibrateEnabled(), true);
    expect(await repo.getGroupByThread(), true);
    expect(await repo.getMaxNotifications(), 5);
    expect(await repo.getAllowRemoteImages(), false);

    // set/get
    await repo.setQuietHours(const QuietHours(startHour: 21, endHour: 6));
    qh = await repo.getQuietHours();
    expect(qh.startHour, 21);
    expect(qh.endHour, 6);

    await repo.setSoundEnabled(false);
    expect(await repo.getSoundEnabled(), false);

    await repo.setVibrateEnabled(false);
    expect(await repo.getVibrateEnabled(), false);

    await repo.setGroupByThread(false);
    expect(await repo.getGroupByThread(), false);

    await repo.setMaxNotifications(7);
    expect(await repo.getMaxNotifications(), 7);

    await repo.setAllowRemoteImages(true);
    expect(await repo.getAllowRemoteImages(), true);
  });
}
