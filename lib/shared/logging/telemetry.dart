import 'dart:developer' as dev;
import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import '../utils/hashing.dart';

class Telemetry {
  Telemetry._();

  // Optional test hook
  static void Function(String name, Map<String, Object?> props)? onEvent;

  static Map<String, Object?> _baseProps() {
    // For P11 scope and tests, route path as 'legacy' (flags off). No GetStorage dependencies here.
    return {
      'path': 'legacy',
    };
  }

  static void event(String name, {Map<String, Object?> props = const {}}) {
    final merged = {..._baseProps(), ..._redactProps(props)};
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
}
