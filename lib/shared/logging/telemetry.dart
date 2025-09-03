import 'dart:developer' as dev;
import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import '../utils/hashing.dart';

class Telemetry {
  Telemetry._();

  // Optional test hook
  static void Function(String name, Map<String, Object?> props)? onEvent;

  // Lightweight in-memory rollups (dev-only aid). Not persisted.
  static final Map<String, _OpStats> _stats = <String, _OpStats>{};
  static int _searchSuccess = 0;
  static int _searchFailure = 0;

  static Map<String, Object?> _baseProps() {
    // For P11 scope and tests, route path as 'legacy' (flags off). No GetStorage dependencies here.
    return {
      'path': 'legacy',
    };
  }

  static void event(String name, {Map<String, Object?> props = const {}}) {
    final merged = {..._baseProps(), ..._redactProps(props)};

    // Update rollups (best-effort)
    try {
      _ingestForRollup(name, merged);
    } catch (_) {}

    // Always log to developer log; print to console only in debug for visibility
    dev.log(
      name,
      name: 'telemetry',
      error: null,
      stackTrace: null,
      time: DateTime.now(),
      sequenceNumber: null,
    );
    if (kDebugMode) {
      // ignore: avoid_print
      print('[telemetry] $name $merged');
    }
    // test hook
    try {
      onEvent?.call(name, merged);
    } catch (_) {}
  }

  static T time<T>(
    String name,
    T Function() f, {
    Map<String, Object?> props = const {},
  }) {
    final sw = Stopwatch()..start();
    try {
      return f();
    } finally {
      sw.stop();
      event(name, props: {...props, 'ms': sw.elapsedMilliseconds});
    }
  }

  static Future<T> timeAsync<T>(
    String name,
    Future<T> Function() f, {
    Map<String, Object?> props = const {},
  }) async {
    final sw = Stopwatch()..start();
    try {
      return await f();
    } finally {
      sw.stop();
      event(name, props: {...props, 'ms': sw.elapsedMilliseconds});
    }
  }

  static Map<String, Object?> _redactProps(Map<String, Object?> props) {
    if (kReleaseMode) {
      final out = <String, Object?>{};
      props.forEach((k, v) {
        if (v is String &&
            (k.contains('email') ||
                k.contains('account') ||
                k.contains('uid'))) {
          out[k] = Hashing.djb2(v).toString();
        } else {
          out[k] = v;
        }
      });
      return out;
    }
    return props;
  }

  // Expose a snapshot of rollups for debugging/QA
  static Map<String, Object?> rollupSnapshot() {
    final out = <String, Object?>{};
    // Success rate for search
    final totalSearch = _searchSuccess + _searchFailure;
    final searchRate = totalSearch == 0 ? 0.0 : (_searchSuccess / totalSearch);
    out['search_success_rate'] = searchRate;

    // Repository/global error rate (events with error_class)
    int totalWithErrors = 0;
    int totalEvents = 0;
    _stats.forEach((op, s) {
      totalWithErrors += s.errors;
      totalEvents += s.count;
      out['${op}_p50_ms'] = s.percentile(50);
      out['${op}_p95_ms'] = s.percentile(95);
    });
    out['repository_error_rate'] = totalEvents == 0 ? 0.0 : (totalWithErrors / totalEvents);
    return out;
  }

  static void resetRollup() {
    _stats.clear();
    _searchSuccess = 0;
    _searchFailure = 0;
  }

  static void _ingestForRollup(String name, Map<String, Object?> props) {
    // success/failure shorthand for search
    if (name == 'search_success') _searchSuccess++;
    if (name == 'search_failure') _searchFailure++;

    final op = (props['op'] ?? name).toString();
    final lat = (props['lat_ms'] ?? props['ms']);
    final err = props['error_class'];
    final s = _stats.putIfAbsent(op, () => _OpStats(maxSamples: 500));
    s.count += 1;
    if (err != null) s.errors += 1;
    if (lat is int) s.addLatency(lat);
    if (lat is double) s.addLatency(lat.toInt());
  }
}

class _OpStats {
  int count = 0;
  int errors = 0;
  final int maxSamples;
  final List<int> _latencies = <int>[];
  _OpStats({this.maxSamples = 500});
  void addLatency(int ms) {
    _latencies.add(ms);
    if (_latencies.length > maxSamples) {
      _latencies.removeAt(0);
    }
  }
  int percentile(int p) {
    if (_latencies.isEmpty) return 0;
    final copy = List<int>.from(_latencies)..sort();
    final idx = ((p / 100) * (copy.length - 1)).round();
    return copy[idx];
  }
}
