import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Lightweight performance tracer for Timeline sections and frame timing sampling.
///
/// Usage:
///   final end = PerfTracer.begin('storage.loadPage');
///   // ... work ...
///   end();
///
/// Or
///   PerfTracer.trace('controller.fetchMailbox', () async { ... });
class PerfTracer {
  static bool enabled =
      kProfileMode || kReleaseMode; // enable in profile/release by default

  static void Function() begin(String name, {Map<String, Object?>? args}) {
    if (!enabled) return _noop;
    dev.Timeline.startSync(name, arguments: args);
    return () {
      try {
        dev.Timeline.finishSync();
      } catch (_) {}
    };
  }

  static Future<T> trace<T>(
    String name,
    Future<T> Function() fn, {
    Map<String, Object?>? args,
  }) async {
    if (!enabled) return fn();
    final end = begin(name, args: args);
    try {
      return await fn();
    } finally {
      end();
    }
  }
}

/// Frame timing sampler that can be enabled during perf tests to compute
/// average frame time and jank metrics (very basic).
class FrameTimingSampler {
  final List<FrameTiming> _timings = <FrameTiming>[];
  bool _attached = false;

  void attach() {
    if (_attached) return;
    SchedulerBinding.instance.addTimingsCallback(_collect);
    _attached = true;
  }

  void detach() {
    if (!_attached) return;
    SchedulerBinding.instance.removeTimingsCallback(_collect);
    _attached = false;
  }

  void reset() => _timings.clear();

  void _collect(List<FrameTiming> timings) {
    _timings.addAll(timings);
  }

  Map<String, Object> summarize() {
    if (_timings.isEmpty) {
      return {
        'frames': 0,
        'avg_total_ms': 0.0,
        'p95_total_ms': 0.0,
        'janky_pct': 0.0,
      };
    }
    final totals =
        _timings.map((t) => t.totalSpan.inMicroseconds / 1000.0).toList()
          ..sort();
    final frames = totals.length;
    final avg = totals.reduce((a, b) => a + b) / frames;
    final p95 = totals[(frames * 0.95).floor().clamp(0, frames - 1)];
    final janky = totals.where((ms) => ms > 16.0).length / frames * 100.0;
    return {
      'frames': frames,
      'avg_total_ms': avg,
      'p95_total_ms': p95,
      'janky_pct': janky,
    };
  }
}

void _noop() {}
