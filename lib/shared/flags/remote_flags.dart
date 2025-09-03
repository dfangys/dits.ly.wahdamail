import 'dart:convert';
import 'package:get_storage/get_storage.dart';
import 'package:injectable/injectable.dart';

/// Remote flags loader (dev stub).
/// - Non-blocking load from a local JSON/stored map key.
/// - Overrides are kept in-memory; getters return null if not specified.
@lazySingleton
class RemoteFlags {
  static const String _kStoreKey = 'remote.flags.payload'; // JSON string or Map
  final GetStorage _box = GetStorage();

  Map<String, dynamic> _overrides = const {};
  bool _loaded = false;

  Future<void> load() async {
    try {
      final raw = _box.read(_kStoreKey);
      if (raw is String && raw.trim().isNotEmpty) {
        _overrides = json.decode(raw) as Map<String, dynamic>;
      } else if (raw is Map<String, dynamic>) {
        _overrides = raw;
      }
      _loaded = true;
    } catch (_) {
      // keep empty overrides on parse errors
      _loaded = true;
    }
  }

  bool? getBool(String key) {
    final v = _overrides[key];
    if (v is bool) return v;
    if (v is String) {
      if (v.toLowerCase() == 'true') return true;
      if (v.toLowerCase() == 'false') return false;
    }
    return null;
  }

  bool get isLoaded => _loaded;
}

