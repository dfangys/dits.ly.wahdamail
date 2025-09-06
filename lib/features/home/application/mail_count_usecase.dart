import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:get_storage/get_storage.dart';

/// Use-case for unread/badge counts per mailbox.
///
/// For P12.4c we mirror existing behavior by sourcing from GetStorage:
/// - Seed from 'boxes' (BoxModel) and per-mailbox persisted keys like '<name>_count'
/// - Expose a stream per mailbox name for UI binding.
@lazySingleton
class MailCountUseCase {
  final GetStorage _storage = GetStorage();
  final Map<String, StreamController<int>> _controllers = {};

  /// Returns a stream of unread counts for a given mailbox name.
  Stream<int> unreadCountForMailbox(String mailboxName) {
    final key = mailboxName.toLowerCase();
    final ctrl = _controllers.putIfAbsent(key, () {
      final c = StreamController<int>.broadcast();
      c.add(_initialUnreadFor(key));
      return c;
    });
    return ctrl.stream;
  }

  /// Synchronous initial count used for initialData in StreamBuilder.
  int initialUnreadForMailbox(String mailboxName) => _initialUnreadFor(mailboxName.toLowerCase());

  /// Explicit updater (currently unused by legacy code, but available for future wiring).
  void updateCount(String mailboxName, int value) {
    final key = mailboxName.toLowerCase();
    _storage.write('${key}_count', value);
    final ctrl = _controllers[key];
    if (ctrl != null && !ctrl.isClosed) ctrl.add(value);
  }

  int _initialUnreadFor(String mailboxKey) {
    // 1) Per-mailbox persisted value if any
    final stored = _storage.read<int>('${mailboxKey}_count');
    if (stored != null) return stored;
    // 2) Fallback to messagesUnseen from 'boxes' list
    final boxes = (_storage.read<List>('boxes') ?? []).cast<Map<String, dynamic>>();
    for (final j in boxes) {
      final name = (j['name'] as String?) ?? (j['encodedName'] as String?) ?? '';
      if (name.toLowerCase() == mailboxKey) {
        final mu = j['messagesUnseen'];
        if (mu is int) return mu;
        if (mu is double) return mu.toInt();
        if (mu is String) return int.tryParse(mu) ?? 0;
        return 0;
      }
    }
    return 0;
  }
}

