import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_storage/get_storage.dart';
import 'package:injectable/injectable.dart';

/// Canonical auth token store for MailSys API.
/// - Persists to disk (GetStorage)
/// - Keeps an in-memory cache for fast reads
/// - Emits a stream on changes
@lazySingleton
class SecureTokenStore {
  static const String _key = 'mailsys_token';
  final GetStorage _box = GetStorage();

  String? _current;
  final StreamController<String?> _controller =
      StreamController<String?>.broadcast();

  /// Current token in memory (null if none loaded)
  String? get current => _current;

  /// Subscribe to token changes
  Stream<String?> get stream => _controller.stream;

  /// Prime memory from disk on boot. Returns true if a token was found.
  Future<bool> primeFromDisk() async {
    try {
      final t = _box.read<String>(_key);
      _current = (t != null && t.isNotEmpty) ? t : null;
      if (kDebugMode) {
        // ignore: avoid_print
        print('[Auth] primeFromDisk: tokenPresent=${_current != null}');
      }
      _controller.add(_current);
      return _current != null;
    } catch (_) {
      _current = null;
      _controller.add(_current);
      return false;
    }
  }

  /// Persist and publish a new token
  Future<void> write(String token) async {
    await _box.write(_key, token);
    _current = token;
    _controller.add(_current);
  }

  /// Clear token from disk and memory
  Future<void> clear() async {
    await _box.remove(_key);
    _current = null;
    _controller.add(_current);
  }
}

