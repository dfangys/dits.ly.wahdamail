import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';

enum DraftSyncBadgeState { idle, syncing, synced, failed }

class DraftSyncService {
  DraftSyncService._();
  static final DraftSyncService instance = DraftSyncService._();

  // Map of message key -> state
  final RxMap<String, DraftSyncBadgeState> _states = <String, DraftSyncBadgeState>{}.obs;

  String keyFor(Mailbox mailbox, MimeMessage message) {
    final id = message.uid ?? message.sequenceId ?? 0;
    return '${mailbox.encodedPath}:$id';
  }

  DraftSyncBadgeState stateFor(Mailbox mailbox, MimeMessage message) {
    return _states[keyFor(mailbox, message)] ?? DraftSyncBadgeState.idle;
  }

  void setStateFor(Mailbox mailbox, MimeMessage message, DraftSyncBadgeState state) {
    _states[keyFor(mailbox, message)] = state;
    _states.refresh();
  }

  void setStateForKey(String key, DraftSyncBadgeState state) {
    _states[key] = state;
    _states.refresh();
  }

  void clearFor(Mailbox mailbox, MimeMessage message) {
    _states.remove(keyFor(mailbox, message));
    _states.refresh();
  }

  void clearKey(String key) {
    _states.remove(key);
    _states.refresh();
  }

  RxMap<String, DraftSyncBadgeState> get states => _states;
}

