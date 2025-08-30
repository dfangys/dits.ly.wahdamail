import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

/// Simple Outbox queue to persist optimistic "Sent" entries across restarts.
///
/// Stores lightweight metadata only, keyed by a unique optimistic ID so the UI
/// can restore badges or pending states if the app restarts before server
/// confirmation.
class OutboxService {
  OutboxService._();
  static final OutboxService instance = OutboxService._();

  static const String _storageKey = 'outbox_entries_v1';
  final GetStorage _store = GetStorage();

  // key -> metadata map
  final RxMap<String, Map<String, dynamic>> _entries = <String, Map<String, dynamic>>{}.obs;
  RxMap<String, Map<String, dynamic>> get entries => _entries;

  Future<void> init() async {
    try {
      final raw = _store.read(_storageKey);
      if (raw is Map) {
        _entries.assignAll(raw.cast<String, Map<String, dynamic>>());
      }
    } catch (_) {}
  }

  void _persist() {
    try {
      _store.write(_storageKey, _entries);
    } catch (_) {}
  }

  /// Add an optimistic entry.
  /// meta can include subject, dateEpoch, mailboxPath, preview, etc.
  void add(String key, Map<String, dynamic> meta) {
    _entries[key] = {
      ...meta,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
    _entries.refresh();
    _persist();
  }

  /// Remove an entry once the send/append is confirmed or rolled back.
  void remove(String key) {
    _entries.remove(key);
    _entries.refresh();
    _persist();
  }

  /// Clear all (rarely used)
  void clear() {
    _entries.clear();
    _persist();
  }
}

