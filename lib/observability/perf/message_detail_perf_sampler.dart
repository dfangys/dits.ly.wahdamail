import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';

/// MessageDetailPerfSampler
/// Captures frame timings while active and emits a single telemetry event on stop.
/// Fields: op, latency_ms, jank_frames, total_frames, dropped_pct, request_id (optional)
class MessageDetailPerfSampler {
  final String
  opName; // e.g. "message_detail_render", "message_detail_body_scroll"
  final String? requestId;

  static const double _frameBudgetMs = 16.67; // 60Hz

  bool _active = false;
  late final DateTime _startAt;
  final List<FrameTiming> _frames = <FrameTiming>[];
  final List<double> _syntheticFrameMs = <double>[]; // for tests
  TimingsCallback? _timingsCallback;

  MessageDetailPerfSampler({required this.opName, this.requestId});

  void start() {
    if (_active) return;
    _active = true;
    _startAt = DateTime.now();
    _timingsCallback = (List<FrameTiming> timings) {
      if (!_active) return;
      _frames.addAll(timings);
    };
    SchedulerBinding.instance.addTimingsCallback(_timingsCallback!);
  }

  void stop() {
    if (!_active) return;
    _active = false;
    if (_timingsCallback != null) {
      SchedulerBinding.instance.removeTimingsCallback(_timingsCallback!);
      _timingsCallback = null;
    }
    final summary = buildSummary();
    Telemetry.event('operation', props: summary);
  }

  Map<String, Object?> buildSummary() {
    final durMs = DateTime.now().difference(_startAt).inMilliseconds;
    final totalFrames =
        _frames.isNotEmpty ? _frames.length : _syntheticFrameMs.length;
    int jank = 0;
    if (_frames.isNotEmpty) {
      for (final f in _frames) {
        final total = (f.totalSpan.inMicroseconds) / 1000.0; // ms
        if (total > _frameBudgetMs) jank++;
      }
    } else {
      for (final ms in _syntheticFrameMs) {
        if (ms > _frameBudgetMs) jank++;
      }
    }
    final droppedPct = totalFrames == 0 ? 0.0 : (jank / totalFrames) * 100.0;
    return <String, Object?>{
      'op': opName,
      'latency_ms': durMs,
      'jank_frames': jank,
      'total_frames': totalFrames,
      'dropped_pct': double.parse(droppedPct.toStringAsFixed(2)),
      if (requestId != null) 'request_id': requestId,
    };
  }

  @visibleForTesting
  void ingestSyntheticFrameDurations(List<double> frameMs) {
    _syntheticFrameMs.addAll(frameMs);
  }
}
