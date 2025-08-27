import 'package:get_storage/get_storage.dart';

/// Simple feature flags for staged rollout of performance features.
/// Defaults are enabled, can be overridden via GetStorage keys or env.
class FeatureFlags {
  FeatureFlags._();
  static final FeatureFlags instance = FeatureFlags._();

  static const _kPerTileNotifiers = 'ff_per_tile_notifiers_enabled';
  static const _kVirtualizationTuning = 'ff_virtualization_tuning_enabled';
  static const _kPreviewWorker = 'ff_preview_worker_enabled';
  static const _kAnimationsCapped = 'ff_animations_capped_enabled';
  static const _kFixedExtentList = 'ff_fixed_extent_list_enabled';

  final GetStorage _box = GetStorage();

  bool get perTileNotifiersEnabled => _box.read(_kPerTileNotifiers) ?? true;
  bool get virtualizationTuningEnabled => _box.read(_kVirtualizationTuning) ?? true;
  bool get previewWorkerEnabled => _box.read(_kPreviewWorker) ?? true;
  bool get animationsCappedEnabled => _box.read(_kAnimationsCapped) ?? true;
  bool get fixedExtentListEnabled => _box.read(_kFixedExtentList) ?? false;

  Future<void> setPerTileNotifiers(bool enabled) => _box.write(_kPerTileNotifiers, enabled);
  Future<void> setVirtualizationTuning(bool enabled) => _box.write(_kVirtualizationTuning, enabled);
  Future<void> setPreviewWorker(bool enabled) => _box.write(_kPreviewWorker, enabled);
  Future<void> setAnimationsCapped(bool enabled) => _box.write(_kAnimationsCapped, enabled);
  Future<void> setFixedExtentList(bool enabled) => _box.write(_kFixedExtentList, enabled);
}

