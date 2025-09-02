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

  // New flags for mail sync behavior
  static const _kForegroundPollingEnabled = 'ff_foreground_polling_enabled';
  static const _kForegroundPollingIntervalSecs =
      'ff_foreground_polling_interval_secs';
  static const _kAttachmentPrefetchEnabled = 'ff_attachment_prefetch_enabled';
  // Offline HTML materialization flags
  static const _kHtmlMaterializationEnabled = 'ff_html_materialization_enabled';
  static const _kHtmlMaterializationThresholdBytes =
      'ff_html_materialization_threshold_bytes';
  static const _kHtmlMaterializeInitialWindow =
      'ff_html_materialize_initial_window';
  // Draft compose settings
  static const _kDraftAutosaveIntervalSecs = 'ff_draft_autosave_interval_secs';
  static const _kDraftKeepRecentCount = 'ff_draft_keep_recent_count';

  // DDD migration flags (P0 defaults: all false; shadow_mode true when used)
  static const _kDddMessagingEnabled = 'ddd.messaging.enabled';
  static const _kDddSendEnabled = 'ddd.send.enabled';
  static const _kDddSyncShadowMode = 'ddd.sync.shadow_mode';
  static const _kDddSearchEnabled = 'ddd.search.enabled';
  static const _kDddNotificationsEnabled = 'ddd.notifications.enabled';
  static const _kDddEnterpriseApiEnabled = 'ddd.enterprise_api.enabled';

  final GetStorage _box = GetStorage();

  bool get perTileNotifiersEnabled => _box.read(_kPerTileNotifiers) ?? true;
  bool get virtualizationTuningEnabled =>
      _box.read(_kVirtualizationTuning) ?? true;
  bool get previewWorkerEnabled => _box.read(_kPreviewWorker) ?? true;
  bool get animationsCappedEnabled => _box.read(_kAnimationsCapped) ?? true;
  bool get fixedExtentListEnabled => _box.read(_kFixedExtentList) ?? false;

  // New getters with sensible defaults
  bool get foregroundPollingEnabled =>
      _box.read(_kForegroundPollingEnabled) ?? true;
  int get foregroundPollingIntervalSecs =>
      (_box.read(_kForegroundPollingIntervalSecs) as int?) ?? 90;
  bool get attachmentPrefetchEnabled =>
      _box.read(_kAttachmentPrefetchEnabled) ?? false;

  // Offline HTML materialization getters
  bool get htmlMaterializationEnabled =>
      _box.read(_kHtmlMaterializationEnabled) ?? true;
  int get htmlMaterializationThresholdBytes =>
      (_box.read(_kHtmlMaterializationThresholdBytes) as int?) ?? (64 * 1024);
  bool get htmlMaterializeInitialWindow =>
      _box.read(_kHtmlMaterializeInitialWindow) ?? true;

  // Draft compose getters
  int get draftAutosaveIntervalSecs =>
      (_box.read(_kDraftAutosaveIntervalSecs) as int?) ?? 30;
  int get draftKeepRecentCount =>
      (_box.read(_kDraftKeepRecentCount) as int?) ?? 1;

  // DDD getters
  bool get dddMessagingEnabled => _box.read(_kDddMessagingEnabled) ?? false;
  bool get dddSendEnabled => _box.read(_kDddSendEnabled) ?? false;
  bool get dddSyncShadowMode => _box.read(_kDddSyncShadowMode) ?? false;
  bool get dddSearchEnabled => _box.read(_kDddSearchEnabled) ?? false;
  bool get dddNotificationsEnabled =>
      _box.read(_kDddNotificationsEnabled) ?? false;
  bool get dddEnterpriseApiEnabled =>
      _box.read(_kDddEnterpriseApiEnabled) ?? false;

  // Telemetry path helper
  static String get telemetryPath {
    final ff = FeatureFlags.instance;
    return (ff.dddMessagingEnabled ||
            ff.dddSendEnabled ||
            ff.dddSearchEnabled ||
            ff.dddNotificationsEnabled ||
            ff.dddEnterpriseApiEnabled)
        ? 'ddd'
        : 'legacy';
  }

  Future<void> setPerTileNotifiers(bool enabled) =>
      _box.write(_kPerTileNotifiers, enabled);
  Future<void> setVirtualizationTuning(bool enabled) =>
      _box.write(_kVirtualizationTuning, enabled);
  Future<void> setPreviewWorker(bool enabled) =>
      _box.write(_kPreviewWorker, enabled);
  Future<void> setAnimationsCapped(bool enabled) =>
      _box.write(_kAnimationsCapped, enabled);
  Future<void> setFixedExtentList(bool enabled) =>
      _box.write(_kFixedExtentList, enabled);

  // New setters
  Future<void> setForegroundPollingEnabled(bool enabled) =>
      _box.write(_kForegroundPollingEnabled, enabled);
  Future<void> setForegroundPollingIntervalSecs(int seconds) =>
      _box.write(_kForegroundPollingIntervalSecs, seconds);
  Future<void> setAttachmentPrefetchEnabled(bool enabled) =>
      _box.write(_kAttachmentPrefetchEnabled, enabled);

  // Draft compose setters
  Future<void> setDraftAutosaveIntervalSecs(int seconds) =>
      _box.write(_kDraftAutosaveIntervalSecs, seconds);
  Future<void> setDraftKeepRecentCount(int count) =>
      _box.write(_kDraftKeepRecentCount, count);

  // Offline HTML materialization setters
  Future<void> setHtmlMaterializationEnabled(bool enabled) =>
      _box.write(_kHtmlMaterializationEnabled, enabled);
  Future<void> setHtmlMaterializationThresholdBytes(int bytes) =>
      _box.write(_kHtmlMaterializationThresholdBytes, bytes);
  Future<void> setHtmlMaterializeInitialWindow(bool enabled) =>
      _box.write(_kHtmlMaterializeInitialWindow, enabled);
}
