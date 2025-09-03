import 'package:injectable/injectable.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';

/// Minimal tracing utility; no-op unless enabled via env/test override.
@lazySingleton
class Tracing {
  static const bool _kEnabled = bool.fromEnvironment('TRACING_ENABLED', defaultValue: false);
  static bool? _testEnabled;

  static void enableForTests(bool enabled) => _testEnabled = enabled;

  static bool get _enabled => _testEnabled ?? _kEnabled;

  static _Span startSpan(String name, {Map<String, Object?> attrs = const {}}) {
    if (!_enabled) return _Span.off(name);
    return _Span.on(name, attrs);
  }

  static void end(_Span span, {String? errorClass, Map<String, Object?> attrs = const {}}) {
    if (!_enabled) return;
    if (!span.on) return;
    final ms = DateTime.now().difference(span.start).inMilliseconds;
    final props = <String, Object?>{
      ...span.attrs,
      ...attrs,
      if (errorClass != null) 'err_type': errorClass,
      'latency_ms': ms,
      'span': span.name,
      'op': 'span',
    };
    Telemetry.event('span', props: props);
  }
}

class _Span {
  final String name;
  final DateTime start;
  final Map<String, Object?> attrs;
  final bool on;
  _Span.on(this.name, this.attrs)
      : start = DateTime.now(),
        on = true;
  _Span.off(this.name)
      : start = DateTime.fromMillisecondsSinceEpoch(0),
        attrs = const {},
        on = false;
}

