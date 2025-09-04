import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';

/// ListPerfSampler
/// Lightweight frame and scroll sampler for list views.
/// - Captures FrameTiming while active
/// - Tracks instantaneous scroll velocity (px/s) from a ScrollController
/// - On stop(), emits a single telemetry event with aggregated metrics
///
/// This utility is dev-only observability and does not alter app behavior.
class ListPerfSampler {
  final String opName; // e.g. "mailbox_list_scroll", "search_list_scroll"
  final ScrollController scrollController;
  final String? requestId;

  // Config
  static const double _frameBudgetMs = 16.67; // 60Hz frame budget

  // State
  bool _active = false;
  late final DateTime _startAt;
  final List<FrameTiming> _frames = <FrameTiming>[];
  final List<double> _velocities = <double>[]; // px/s
  final List<_Sample> _samples = <_Sample>[]; // for velocity derivation
  final List<double> _syntheticFrameMs = <double>[]; // test-only frames when real timings unavailable
  VoidCallback? _scrollListener;
  TimingsCallback? _timingsCallback;

  ListPerfSampler({
    required this.opName,
    required this.scrollController,
    this.requestId,
  });

  void start() {
    if (_active) return;
    _active = true;
    _startAt = DateTime.now();

    // Attach frame timings callback
    _timingsCallback = (List<FrameTiming> timings) {
      if (!_active) return;
      _frames.addAll(timings);
    };
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback!);

    // Attach scroll listener for velocity sampling
    double? lastOffset;
    int? lastMicros;
    _scrollListener = () {
      if (!_active || !scrollController.hasClients) return;
      final now = DateTime.now().microsecondsSinceEpoch;
      final offset = scrollController.position.pixels;
      if (lastOffset != null && lastMicros != null) {
        final dtMicros = now - lastMicros!;
        if (dtMicros > 0) {
          final dtSec = dtMicros / 1e6;
          final v = (offset - lastOffset!) / dtSec; // px/s
          if (v.isFinite && v.abs() < 1e6) {
            _velocities.add(v.abs()); // magnitude only
            _samples.add(_Sample(timeMicros: now, offset: offset));
          }
        }
      } else {
        _samples.add(_Sample(timeMicros: now, offset: offset));
      }
      lastMicros = now;
      lastOffset = offset;
    };
    scrollController.addListener(_scrollListener!);
  }

  void stop() {
    if (!_active) return;
    _active = false;

    if (_timingsCallback != null) {
      SchedulerBinding.instance.removeTimingsCallback(_timingsCallback!);
      _timingsCallback = null;
    }
    if (_scrollListener != null) {
      scrollController.removeListener(_scrollListener!);
      _scrollListener = null;
    }

    final summary = buildSummary();
    Telemetry.event('operation', props: summary);
  }

  /// Build the telemetry map without emitting (useful for tests and scripts)
  Map<String, Object?> buildSummary() {
    final durMs = DateTime.now().difference(_startAt).inMilliseconds;
    final totalFrames = _frames.isNotEmpty ? _frames.length : _syntheticFrameMs.length;
    int jankFrames = 0;
    if (_frames.isNotEmpty) {
      for (final f in _frames) {
        // Consider a frame "janky" if total span exceeds budget
        final total = (f.totalSpan.inMicroseconds) / 1000.0; // ms
        if (total > _frameBudgetMs) jankFrames++;
      }
    } else {
      for (final ms in _syntheticFrameMs) {
        if (ms > _frameBudgetMs) jankFrames++;
      }
    }
    final droppedPct = totalFrames == 0 ? 0.0 : (jankFrames / totalFrames) * 100.0;

    // Use median velocity to reduce outliers impact
    final medianVelocity = _velocities.isEmpty ? 0.0 : _percentile(_velocities, 50);

    return <String, Object?>{
      'op': opName,
      'latency_ms': durMs,
      'jank_frames': jankFrames,
      'total_frames': totalFrames,
      'dropped_pct': double.parse(droppedPct.toStringAsFixed(2)),
      'scroll_velocity_px_s': medianVelocity.round(),
      if (requestId != null) 'request_id': requestId,
    };
  }

  // Test helpers: allow injecting synthetic timings for deterministic unit tests
  @visibleForTesting
  void ingestFrameTimings(List<FrameTiming> frames) {
    _frames.addAll(frames);
  }

  @visibleForTesting
  void ingestVelocitySamples(List<double> velocitiesPxPerSec) {
    _velocities.addAll(velocitiesPxPerSec.where((v) => v.isFinite));
  }

  /// Test-only helper to bypass FrameTiming construction and push synthetic frame durations (ms)
  @visibleForTesting
  void ingestSyntheticFrameDurations(List<double> frameMs) {
    _syntheticFrameMs.addAll(frameMs);
  }

  @visibleForTesting
  double percentileVelocity(int p) => _percentile(_velocities, p);

  static double _percentile(List<double> values, int p) {
    if (values.isEmpty) return 0.0;
    final copy = List<double>.from(values)..sort();
    final idx = ((p / 100) * (copy.length - 1)).round();
    return copy[idx];
  }
}

class _Sample {
  final int timeMicros;
  final double offset;
  _Sample({required this.timeMicros, required this.offset});
}

