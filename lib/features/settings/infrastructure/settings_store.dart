import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/features/settings/domain/settings_repository.dart';

class SettingsStore implements SettingsRepository {
  final GetStorage _box;
  SettingsStore(this._box);

  // Defaults documented; no behavior change in P9
  static const _kQhStart = 'quiet_hours_start';
  static const _kQhEnd = 'quiet_hours_end';
  static const _kSound = 'notif_sound_enabled';
  static const _kVibrate = 'notif_vibrate_enabled';
  static const _kGroup = 'notif_group_by_thread';
  static const _kMax = 'notif_max';
  static const _kRemoteImg = 'allow_remote_images';

  @override
  Future<QuietHours> getQuietHours() async {
    final start = _box.read(_kQhStart) as int? ?? 22;
    final end = _box.read(_kQhEnd) as int? ?? 7;
    return QuietHours(startHour: start, endHour: end);
  }

  @override
  Future<void> setQuietHours(QuietHours qh) async {
    await _box.write(_kQhStart, qh.startHour);
    await _box.write(_kQhEnd, qh.endHour);
  }

  @override
  Future<bool> getSoundEnabled() async => (_box.read(_kSound) as bool?) ?? true;
  @override
  Future<void> setSoundEnabled(bool v) async => _box.write(_kSound, v);

  @override
  Future<bool> getVibrateEnabled() async =>
      (_box.read(_kVibrate) as bool?) ?? true;
  @override
  Future<void> setVibrateEnabled(bool v) async => _box.write(_kVibrate, v);

  @override
  Future<bool> getGroupByThread() async =>
      (_box.read(_kGroup) as bool?) ?? true;
  @override
  Future<void> setGroupByThread(bool v) async => _box.write(_kGroup, v);

  @override
  Future<int> getMaxNotifications() async => (_box.read(_kMax) as int?) ?? 5;
  @override
  Future<void> setMaxNotifications(int v) async => _box.write(_kMax, v);

  @override
  Future<bool> getAllowRemoteImages() async =>
      (_box.read(_kRemoteImg) as bool?) ?? false;
  @override
  Future<void> setAllowRemoteImages(bool v) async => _box.write(_kRemoteImg, v);
}

class FakeStorageSettings implements SettingsRepository {
  final Map<String, Object?> _m = {};
  static const _kQhStart = 'quiet_hours_start';
  static const _kQhEnd = 'quiet_hours_end';
  static const _kSound = 'notif_sound_enabled';
  static const _kVibrate = 'notif_vibrate_enabled';
  static const _kGroup = 'notif_group_by_thread';
  static const _kMax = 'notif_max';
  static const _kRemoteImg = 'allow_remote_images';

  @override
  Future<QuietHours> getQuietHours() async {
    final start = _m[_kQhStart] as int? ?? 22;
    final end = _m[_kQhEnd] as int? ?? 7;
    return QuietHours(startHour: start, endHour: end);
  }

  @override
  Future<void> setQuietHours(QuietHours qh) async {
    _m[_kQhStart] = qh.startHour;
    _m[_kQhEnd] = qh.endHour;
  }

  @override
  Future<bool> getSoundEnabled() async => (_m[_kSound] as bool?) ?? true;
  @override
  Future<void> setSoundEnabled(bool v) async => _m[_kSound] = v;

  @override
  Future<bool> getVibrateEnabled() async => (_m[_kVibrate] as bool?) ?? true;
  @override
  Future<void> setVibrateEnabled(bool v) async => _m[_kVibrate] = v;

  @override
  Future<bool> getGroupByThread() async => (_m[_kGroup] as bool?) ?? true;
  @override
  Future<void> setGroupByThread(bool v) async => _m[_kGroup] = v;

  @override
  Future<int> getMaxNotifications() async => (_m[_kMax] as int?) ?? 5;
  @override
  Future<void> setMaxNotifications(int v) async => _m[_kMax] = v;

  @override
  Future<bool> getAllowRemoteImages() async =>
      (_m[_kRemoteImg] as bool?) ?? false;
  @override
  Future<void> setAllowRemoteImages(bool v) async => _m[_kRemoteImg] = v;
}
