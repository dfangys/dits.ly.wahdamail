import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';

/// Memory budgets and sampling service.
///
/// Loads budgets from perf/perf_config.json if present and exposes
/// values in bytes. Provides a Process RSS sampler when available.
class MemoryBudgetService extends GetxService {
  static MemoryBudgetService get instance {
    if (!Get.isRegistered<MemoryBudgetService>()) {
      Get.put(MemoryBudgetService(), permanent: true);
    }
    return Get.find<MemoryBudgetService>();
  }

  // Defaults
  static const int _defaultSteadyStateMbMax = 200;
  static const double _defaultCacheFraction =
      0.5; // 50% of steady-state for caches

  int _steadyStateMaxBytes = _defaultSteadyStateMbMax * 1024 * 1024;
  double _cacheFraction = _defaultCacheFraction;

  int get steadyStateMaxBytes => _steadyStateMaxBytes;
  int get cacheSoftMaxBytes => (_steadyStateMaxBytes * _cacheFraction).toInt();

  /// Testing hook: override budgets without touching disk. Safe for tests only.
  void overrideForTesting({int? steadyStateMaxMb, double? cacheFraction}) {
    if (steadyStateMaxMb != null) {
      _steadyStateMaxBytes = steadyStateMaxMb * 1024 * 1024;
    }
    if (cacheFraction != null) {
      _cacheFraction = cacheFraction;
    }
  }

  @override
  Future<void> onInit() async {
    super.onInit();
    _loadFromPerfConfig();
  }

  void _loadFromPerfConfig() {
    try {
      final file = File('perf/perf_config.json');
      if (!file.existsSync()) return;
      final cfg = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      final mb = (cfg['steady_state_memory_mb_max'] as num?)?.toInt();
      if (mb != null && mb > 50) {
        _steadyStateMaxBytes = mb * 1024 * 1024;
      }
      // Allow optional override for cache fraction later if added to config
    } catch (_) {}
  }

  /// Returns current process resident set size in bytes, if available.
  int sampleProcessRssBytes() {
    try {
      return ProcessInfo.currentRss;
    } catch (_) {
      return 0; // Not supported on some platforms
    }
  }
}
