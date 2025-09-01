import 'dart:async';
import 'package:get_storage/get_storage.dart';
import 'package:flutter/foundation.dart';

/// Cross-process connection heartbeat/lease to avoid exceeding server per-user/IP limits.
///
/// Foreground app (main isolate) should call startHeartbeat() after it connects
/// and stopHeartbeat() when disconnecting. Background tasks should consult
/// shouldSkipBackgroundConnect() before opening a connection; if a recent heartbeat
/// exists, they should no-op to avoid creating an additional concurrent IMAP session.
class ConnectionLease {
  ConnectionLease._();
  static ConnectionLease? _instance;
  static ConnectionLease get instance => _instance ??= ConnectionLease._();

  static const String _hbKey = 'active_connection_heartbeat';
  static const String _ownerKey = 'active_connection_owner';
  static const Duration _heartbeatInterval = Duration(seconds: 10);
  static const Duration _freshThreshold = Duration(seconds: 40);

  Timer? _hbTimer;
  final GetStorage _storage = GetStorage();

  /// Start periodically updating the heartbeat to signal an active foreground connection.
  void startHeartbeat({String owner = 'foreground'}) {
    try {
      _updateHeartbeat(owner: owner);
      _hbTimer?.cancel();
      _hbTimer = Timer.periodic(_heartbeatInterval, (_) {
        _updateHeartbeat(owner: owner);
      });
      if (kDebugMode) {
        print('🔒 ConnectionLease heartbeat started (owner=$owner)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔒 Failed to start heartbeat: $e');
      }
    }
  }

  /// Stop the heartbeat updates.
  void stopHeartbeat() {
    try {
      _hbTimer?.cancel();
      _hbTimer = null;
      if (kDebugMode) {
        print('🔒 ConnectionLease heartbeat stopped');
      }
    } catch (_) {}
  }

  void _updateHeartbeat({required String owner}) {
    final nowIso = DateTime.now().toIso8601String();
    try {
      _storage.write(_hbKey, nowIso);
      _storage.write(_ownerKey, owner);
    } catch (_) {}
  }

  /// Returns true if a recent heartbeat exists, indicating another process (likely the
  /// foreground app) already holds an active connection. Background tasks should skip
  /// connecting in this case to avoid exceeding connection limits.
  static bool shouldSkipBackgroundConnect({Duration? threshold}) {
    try {
      final box = GetStorage();
      final iso = box.read<String>(_hbKey);
      if (iso == null || iso.isEmpty) return false;
      final ts = DateTime.tryParse(iso);
      if (ts == null) return false;
      final ttl = threshold ?? _freshThreshold;
      final age = DateTime.now().difference(ts);
      return age <= ttl;
    } catch (_) {
      return false;
    }
  }
}

