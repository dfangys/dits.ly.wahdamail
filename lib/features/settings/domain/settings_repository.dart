class QuietHours {
  final int startHour; // 0-23
  final int endHour; // 0-23
  const QuietHours({required this.startHour, required this.endHour});
}

abstract class SettingsRepository {
  // Notifications
  Future<QuietHours> getQuietHours();
  Future<void> setQuietHours(QuietHours qh);

  Future<bool> getSoundEnabled();
  Future<void> setSoundEnabled(bool v);

  Future<bool> getVibrateEnabled();
  Future<void> setVibrateEnabled(bool v);

  Future<bool> getGroupByThread();
  Future<void> setGroupByThread(bool v);

  Future<int> getMaxNotifications();
  Future<void> setMaxNotifications(int v);

  Future<bool> getAllowRemoteImages();
  Future<void> setAllowRemoteImages(bool v);
}
