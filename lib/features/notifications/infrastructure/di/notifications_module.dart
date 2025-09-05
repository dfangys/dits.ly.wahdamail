import 'package:injectable/injectable.dart';

import 'package:wahda_bank/features/notifications/domain/ports/notification_port.dart';
import 'package:wahda_bank/features/notifications/infrastructure/notification_adapter.dart';
import 'package:wahda_bank/features/settings/domain/settings_repository.dart';
import 'package:wahda_bank/features/settings/infrastructure/settings_store.dart';
import 'package:get_storage/get_storage.dart';

@module
abstract class NotificationsModule {
  @LazySingleton()
  NotificationPort provideNotificationPort() => NoopNotificationAdapter();

  @LazySingleton()
  SettingsRepository provideSettingsRepository() => SettingsStore(GetStorage());

  @LazySingleton()
  NotificationsCoordinator provideCoordinator(NotificationPort port) =>
      NotificationsCoordinator(port as NoopNotificationAdapter); // disabled until flag flip
}
