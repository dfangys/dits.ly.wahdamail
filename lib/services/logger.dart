import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Simple structured logger for app-wide use.
/// In debug mode it logs verbosely; in release you can wire this to
/// a remote sink (e.g., Crashlytics) by replacing the internals here.
class AppLogger {
  static const String _defaultTag = 'WahdaMail';

  static void d(String message, {String tag = _defaultTag, Object? error, StackTrace? stack}) {
    if (kDebugMode) {
      developer.log(message, name: tag, level: 500, error: error, stackTrace: stack);
    }
  }

  static void i(String message, {String tag = _defaultTag}) {
    // Gate info logs in release to reduce runtime overhead.
    if (kDebugMode) {
      developer.log(message, name: tag, level: 800);
    }
  }

  static void w(String message, {String tag = _defaultTag, Object? error, StackTrace? stack}) {
    developer.log(message, name: tag, level: 900, error: error, stackTrace: stack);
  }

  static void e(String message, {String tag = _defaultTag, Object? error, StackTrace? stack}) {
    developer.log(message, name: tag, level: 1000, error: error, stackTrace: stack);
  }
}

