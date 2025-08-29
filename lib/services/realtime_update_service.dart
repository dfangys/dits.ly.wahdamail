import 'dart:async';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:rxdart/rxdart.dart';
import 'package:logger/logger.dart';

import 'cache_manager.dart';
import 'mail_service.dart';
import 'package:wahda_bank/services/notifications_service.dart';

/// ENHANCED: Real-time update service with event-driven architecture
/// Based on enough_mail_app patterns for high-performance reactive updates
class RealtimeUpdateService extends GetxService {
  static final Logger _logger = Logger();
  static RealtimeUpdateService? _instance;
  static RealtimeUpdateService get instance => _instance ??= RealtimeUpdateService._();
  
  RealtimeUpdateService._();

  MailService? get _mailService {
    try {
      return Get.find<MailService>();
    } catch (e) {
      if (kDebugMode) {
        print('Connection check failed: $e');
      }
      return null;
    }
  }
  CacheManager get _cacheManager => CacheManager.instance;

  // Reactive streams for different types of updates
  final BehaviorSubject<List<MimeMessage>> _messagesStream = BehaviorSubject<List<MimeMessage>>.seeded([]);
  final BehaviorSubject<Map<String, int>> _unreadCountsStream = BehaviorSubject<Map<String, int>>.seeded({});
  final BehaviorSubject<Set<String>> _flaggedMessagesStream = BehaviorSubject<Set<String>>.seeded({});
  final BehaviorSubject<ConnectionStatus> _connectionStatusStream = BehaviorSubject<ConnectionStatus>.seeded(ConnectionStatus.disconnected);
  final BehaviorSubject<SyncStatus> _syncStatusStream = BehaviorSubject<SyncStatus>.seeded(SyncStatus.idle);
  final BehaviorSubject<List<Mailbox>> _mailboxesStream = BehaviorSubject<List<Mailbox>>.seeded([]);

  // Message update streams for specific operations
  final PublishSubject<MessageUpdate> _messageUpdateStream = PublishSubject<MessageUpdate>();
  final PublishSubject<MailboxUpdate> _mailboxUpdateStream = PublishSubject<MailboxUpdate>();
  final PublishSubject<String> _errorStream = PublishSubject<String>();

  // Internal state
  final Map<String, List<MimeMessage>> _mailboxMessages = {};
  final Map<String, int> _unreadCounts = {};
  final Set<String> _flaggedMessages = {};
  
  // Track unique message identifiers per mailbox to avoid duplicates
  final Map<String, Set<String>> _mailboxMessageIds = {};
  // Reverse index: messageId -> mailboxKey
  final Map<String, String> _messageIdToMailboxKey = {};
  
  // Track the highest UID we have already notified per mailbox to avoid
  // treating historical mail as "new" on first IDLE/poll.
  final Map<String, int> _lastNotifiedUid = {};
  // Guard concurrent fetches per mailbox
  final Map<String, bool> _fetchInProgress = {};

  // Use mailbox.path as the canonical key (consistent with existing code)
  String _mbKey(Mailbox m) => m.path;

  String? _messageKey(MimeMessage m) {
    final uid = m.uid;
    if (uid != null) return 'uid:$uid';
    final seq = m.sequenceId;
    if (seq != null) return 'seq:$seq';
    final headerId = m.getHeaderValue('message-id') ?? m.getHeaderValue('Message-ID');
    if (headerId != null && headerId.isNotEmpty) return 'mid:$headerId';
    return null;
  }

  void _indexMessage(String mailboxKey, MimeMessage m) {
    final id = _messageKey(m);
    if (id == null) return;
    _mailboxMessageIds.putIfAbsent(mailboxKey, () => <String>{}).add(id);
    _messageIdToMailboxKey[id] = mailboxKey;
  }

  bool _isDuplicate(String mailboxKey, MimeMessage m) {
    final id = _messageKey(m);
    if (id == null) return false;
    final set = _mailboxMessageIds[mailboxKey];
    return set != null && set.contains(id);
  }

  String? _findMailboxKeyForMessage(MimeMessage m) {
    final id = _messageKey(m);
    if (id == null) return null;
    return _messageIdToMailboxKey[id];
  }

  Timer? _periodicSyncTimer;
  Timer? _connectionCheckTimer;
  bool _isInitialized = false;

  // Getters for reactive streams
  Stream<List<MimeMessage>> get messagesStream => _messagesStream.stream;
  Stream<Map<String, int>> get unreadCountsStream => _unreadCountsStream.stream;
  Stream<Set<String>> get flaggedMessagesStream => _flaggedMessagesStream.stream;
  Stream<ConnectionStatus> get connectionStatusStream => _connectionStatusStream.stream;
  Stream<SyncStatus> get syncStatusStream => _syncStatusStream.stream;
  Stream<List<Mailbox>> get mailboxesStream => _mailboxesStream.stream;
  Stream<MessageUpdate> get messageUpdateStream => _messageUpdateStream.stream;
  Stream<MailboxUpdate> get mailboxUpdateStream => _mailboxUpdateStream.stream;
  Stream<String> get errorStream => _errorStream.stream;

  // Current values
  List<MimeMessage> get currentMessages => _messagesStream.value;
  Map<String, int> get currentUnreadCounts => _unreadCountsStream.value;
  Set<String> get currentFlaggedMessages => _flaggedMessagesStream.value;
  ConnectionStatus get currentConnectionStatus => _connectionStatusStream.value;
  SyncStatus get currentSyncStatus => _syncStatusStream.value;
  List<Mailbox> get currentMailboxes => _mailboxesStream.value;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _initialize();
  }

  @override
  void onClose() {
    _periodicSyncTimer?.cancel();
    _connectionCheckTimer?.cancel();
    _messagesStream.close();
    _unreadCountsStream.close();
    _flaggedMessagesStream.close();
    _connectionStatusStream.close();
    _syncStatusStream.close();
    _mailboxesStream.close();
    _messageUpdateStream.close();
    _mailboxUpdateStream.close();
    _errorStream.close();
    super.onClose();
  }

  Future<void> _initialize() async {
    if (_isInitialized) return;

    try {
      // Start connection monitoring
      _startConnectionMonitoring();
      
      // Start periodic sync
      _startPeriodicSync();
      
      // Load initial data
      await _loadInitialData();
      
      _isInitialized = true;
      
      if (kDebugMode) {
        print('RealtimeUpdateService initialized successfully');
      }
    } catch (e) {
      _errorStream.add('Failed to initialize real-time updates: $e');
      if (kDebugMode) {
        print('RealtimeUpdateService initialization failed: $e');
      }
    }
  }

  void _startConnectionMonitoring() {
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkConnectionStatus();
    });
  }

  void _startPeriodicSync() {
    _periodicSyncTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _performPeriodicSync();
    });
  }

  Future<void> _loadInitialData() async {
    try {
      _syncStatusStream.add(SyncStatus.syncing);
      
      final mailService = _mailService;
      if (mailService == null) {
        _syncStatusStream.add(SyncStatus.error);
        _errorStream.add('MailService not available');
        return;
      }
      
      // Load mailboxes
      if (mailService.client.isConnected) {
        final mailboxes = await mailService.client.listMailboxes();
        _mailboxesStream.add(mailboxes);
        
        // Load messages for inbox
        final inbox = mailboxes.firstWhereOrNull((mb) => mb.isInbox);
        if (inbox != null) {
          await _loadMailboxMessages(inbox);
        }
      }
      
      _syncStatusStream.add(SyncStatus.idle);
    } catch (e) {
      _syncStatusStream.add(SyncStatus.error);
      _errorStream.add('Failed to load initial data: $e');
    }
  }

  Future<void> _checkConnectionStatus() async {
    try {
      final mailService = _mailService;
      if (mailService == null) {
        _connectionStatusStream.add(ConnectionStatus.error);
        return;
      }
      
      if (mailService.client.isConnected) {
        // Check connection status without noop
        _connectionStatusStream.add(ConnectionStatus.connected);
      } else {
        _connectionStatusStream.add(ConnectionStatus.disconnected);
        // Try to reconnect
        await _reconnect();
      }
    } catch (e) {
      _connectionStatusStream.add(ConnectionStatus.error);
      if (kDebugMode) {
        print('Connection check failed: $e');
      }
    }
  }

  Future<void> _reconnect() async {
    try {
      final mailService = _mailService;
      if (mailService == null) {
        _connectionStatusStream.add(ConnectionStatus.error);
        _errorStream.add('MailService not available for reconnection');
        return;
      }
      
      _connectionStatusStream.add(ConnectionStatus.connecting);
      await mailService.connect();
      _connectionStatusStream.add(ConnectionStatus.connected);
    } catch (e) {
      _connectionStatusStream.add(ConnectionStatus.error);
      _errorStream.add('Reconnection failed: $e');
    }
  }

  Future<void> _performPeriodicSync() async {
    if (_syncStatusStream.value == SyncStatus.syncing) return;
    
    try {
      _syncStatusStream.add(SyncStatus.syncing);
      
      // Sync all mailboxes
      for (final mailbox in _mailboxesStream.value) {
        await _syncMailbox(mailbox);
      }
      
      _syncStatusStream.add(SyncStatus.idle);
    } catch (e) {
      _syncStatusStream.add(SyncStatus.error);
      _errorStream.add('Periodic sync failed: $e');
    }
  }

  Future<void> _syncMailbox(Mailbox mailbox) async {
    try {
      final mailService = _mailService;
      if (mailService == null) {
        if (kDebugMode) {
          print('MailService not available for syncing mailbox ${mailbox.name}');
        }
        return;
      }
      
      if (!mailService.client.isConnected) {
        await mailService.connect();
      }
      
      await mailService.client.selectMailbox(mailbox);
      
      // Check for new messages
      final currentCount = _mailboxMessages[mailbox.path]?.length ?? 0;
      if (mailbox.messagesExists > currentCount) {
        await _loadNewMessages(mailbox, currentCount);
      }
      
      // Update unread count
      await _updateUnreadCount(mailbox);
      
    } catch (e) {
      if (kDebugMode) {
        print('Failed to sync mailbox ${mailbox.name}: $e');
      }
    }
  }

  Future<void> _loadNewMessages(Mailbox mailbox, int currentCount) async {
    try {
      final mailService = _mailService;
      if (mailService == null) {
        if (kDebugMode) {
          print('MailService not available for loading new messages');
        }
        return;
      }
      
      final newMessageCount = mailbox.messagesExists - currentCount;
      if (newMessageCount <= 0) return;
      
      // Fetch new messages (envelope to ensure subject/from are ready)
      final newMessages = await mailService.client.fetchMessages(
        mailbox: mailbox,
        count: newMessageCount,
        page: 1,
        fetchPreference: FetchPreference.envelope,
      );
      
      // Cache new messages
      for (final message in newMessages) {
        _cacheManager.cacheMessage(message);
      }
      
      // Emit updates via central notifier (handles de-dup & internal state)
      await notifyNewMessages(newMessages, mailbox: mailbox);
      
    } catch (e) {
      if (kDebugMode) {
        print('Failed to load new messages for ${mailbox.name}: $e');
      }
    }
  }

  Future<void> _updateUnreadCount(Mailbox mailbox) async {
    try {
      final messages = _mailboxMessages[mailbox.path] ?? [];
      final unreadCount = messages.where((m) => !m.isSeen).length;
      
      _unreadCounts[mailbox.path] = unreadCount;
      _unreadCountsStream.add(Map.from(_unreadCounts));
      
    } catch (e) {
      if (kDebugMode) {
        print('Failed to update unread count for ${mailbox.name}: $e');
      }
    }
  }

  // Public methods for manual operations
  Future<void> loadMailboxMessages(Mailbox mailbox) async {
    await _loadMailboxMessages(mailbox);
  }

  Future<void> _loadMailboxMessages(Mailbox mailbox) async {
    try {
      _syncStatusStream.add(SyncStatus.syncing);
      
      final mailService = _mailService;
      if (mailService == null) {
        _syncStatusStream.add(SyncStatus.error);
        _errorStream.add('MailService not available for loading mailbox messages');
        return;
      }
      
      if (!mailService.client.isConnected) {
        await mailService.connect();
      }
      
      await mailService.client.selectMailbox(mailbox);
      
      // Load messages in batches
      const batchSize = 20;
      final totalMessages = mailbox.messagesExists;
      final messages = <MimeMessage>[];
      
      for (int i = 0; i < totalMessages; i += batchSize) {
        final end = (i + batchSize > totalMessages) ? totalMessages : i + batchSize;
        final count = end - i;
        final page = (i ~/ batchSize) + 1;
        
        final batchMessages = await mailService.client.fetchMessages(
          mailbox: mailbox,
          count: count,
          page: page,
          fetchPreference: FetchPreference.envelope,
        );
        messages.addAll(batchMessages);
        
        // Cache messages
        for (final message in batchMessages) {
          _cacheManager.cacheMessage(message);
        }
      }
      
      final mbKey = mailbox.path;
      _mailboxMessages[mbKey] = messages;
      _mailboxMessageIds[mbKey] = {};
      for (final m in messages) { _indexMessage(mbKey, m); }
      
      // Establish baseline so we don't spam "new" events for historical mail
      try {
        final uidNext = mailbox.uidNext;
        if (uidNext != null && uidNext > 0) {
          _lastNotifiedUid[mbKey] = uidNext - 1;
        } else {
          // Fallback to highest UID seen in the loaded page
          int maxUid = 0;
          for (final m in messages) {
            final u = m.uid ?? 0;
            if (u > maxUid) maxUid = u;
          }
          if (maxUid > 0) _lastNotifiedUid[mbKey] = maxUid;
        }
      } catch (_) {}
      
      if (mailbox.isInbox) {
        _messagesStream.add(messages);
      }
      
      await _updateUnreadCount(mailbox);
      _syncStatusStream.add(SyncStatus.idle);
      
    } catch (e) {
      _syncStatusStream.add(SyncStatus.error);
      _errorStream.add('Failed to load mailbox messages: $e');
    }
  }

  Future<void> markMessageAsRead(MimeMessage message) async {
    try {
      final mailService = _mailService;
      if (mailService == null) {
        _errorStream.add('MailService not available for marking message as read');
        throw Exception('MailService not available');
      }
      
      // Ensure we have a valid message identifier
      if (message.uid == null && message.sequenceId == null) {
        throw Exception('Message has no UID or sequence ID');
      }
      
      final sequence = MessageSequence.fromMessage(message);
      
      if (kDebugMode) {
        print('📧 Marking message as read: UID=${message.uid}, SeqId=${message.sequenceId}');
      }
      
      // Perform server operation
      await mailService.client.markSeen(sequence);
      
      if (kDebugMode) {
        print('📧 Successfully marked message as read on server');
      }
      
      // Update local state only after server success
      message.isSeen = true;
      
      // Update unread counts based on the mailbox that contains this message
      final id = _messageKey(message);
      final mailboxKey = (id != null ? _messageIdToMailboxKey[id] : null) ?? mailService.client.selectedMailbox?.path ?? 'INBOX';
      if (_unreadCounts[mailboxKey] != null && _unreadCounts[mailboxKey]! > 0) {
        _unreadCounts[mailboxKey] = _unreadCounts[mailboxKey]! - 1;
        _unreadCountsStream.add(Map.from(_unreadCounts));
      }
      
      // Update streams
      _messageUpdateStream.add(MessageUpdate(
        message: message,
        type: MessageUpdateType.statusChanged,
      ));
      
      // Refresh messages stream for INBOX only
      if (mailboxKey.toUpperCase() == 'INBOX') {
        _messagesStream.add(_mailboxMessages[mailboxKey] ?? []);
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error marking message as read: $e');
      }
      _errorStream.add('Failed to mark message as read: $e');
      rethrow; // Rethrow to trigger rollback in UI
    }
  }

  Future<void> markMessageAsUnread(MimeMessage message) async {
    try {
      final mailService = _mailService;
      if (mailService == null) {
        _errorStream.add('MailService not available for marking message as unread');
        throw Exception('MailService not available');
      }
      
      // Ensure we have a valid message identifier
      if (message.uid == null && message.sequenceId == null) {
        throw Exception('Message has no UID or sequence ID');
      }
      
      final sequence = MessageSequence.fromMessage(message);
      
      if (kDebugMode) {
        print('📧 Marking message as unread: UID=${message.uid}, SeqId=${message.sequenceId}');
      }
      
      // Perform server operation
      await mailService.client.markUnseen(sequence);
      
      if (kDebugMode) {
        print('📧 Successfully marked message as unread on server');
      }
      
      // Update local state only after server success
      message.isSeen = false;
      
      // Update unread counts based on the mailbox that contains this message
      final id = _messageKey(message);
      final mailboxKey = (id != null ? _messageIdToMailboxKey[id] : null) ?? mailService.client.selectedMailbox?.path ?? 'INBOX';
      _unreadCounts[mailboxKey] = (_unreadCounts[mailboxKey] ?? 0) + 1;
      _unreadCountsStream.add(Map.from(_unreadCounts));
      
      // Update streams
      _messageUpdateStream.add(MessageUpdate(
        message: message,
        type: MessageUpdateType.statusChanged,
      ));
      
      // Refresh messages stream for INBOX only
      if (mailboxKey.toUpperCase() == 'INBOX') {
        _messagesStream.add(_mailboxMessages[mailboxKey] ?? []);
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error marking message as unread: $e');
      }
      _errorStream.add('Failed to mark message as unread: $e');
      rethrow; // Rethrow to trigger rollback in UI
    }
  }

  Future<void> flagMessage(MimeMessage message) async {
    try {
      final mailService = _mailService;
      if (mailService == null) {
        _errorStream.add('MailService not available for flagging message');
        return;
      }
      
      final sequence = MessageSequence.fromMessage(message);
      await mailService.client.markFlagged(sequence);
      
      // Update local state
      message.isFlagged = true;
      final messageKey = '${message.uid ?? message.sequenceId}';
      _flaggedMessages.add(messageKey);
      _flaggedMessagesStream.add(Set.from(_flaggedMessages));
      
      // Update streams
      _messageUpdateStream.add(MessageUpdate(
        message: message,
        type: MessageUpdateType.statusChanged,
      ));
      
    } catch (e) {
      _errorStream.add('Failed to flag message: $e');
    }
  }

  Future<void> unflagMessage(MimeMessage message) async {
    try {
      final mailService = _mailService;
      if (mailService == null) {
        _errorStream.add('MailService not available for unflagging message');
        return;
      }
      
      final sequence = MessageSequence.fromMessage(message);
      await mailService.client.markUnflagged(sequence);
      
      // Update local state
      message.isFlagged = false;
      final messageKey = '${message.uid ?? message.sequenceId}';
      _flaggedMessages.remove(messageKey);
      _flaggedMessagesStream.add(Set.from(_flaggedMessages));
      
      // Update streams
      _messageUpdateStream.add(MessageUpdate(
        message: message,
        type: MessageUpdateType.statusChanged,
      ));
      
    } catch (e) {
      _errorStream.add('Failed to unflag message: $e');
    }
  }

  Future<void> deleteMessage(MimeMessage message) async {
    try {
      final mailService = _mailService;
      if (mailService == null) {
        _errorStream.add('MailService not available for deleting message');
        return;
      }
      
      final sequence = MessageSequence.fromMessage(message);
      await mailService.client.deleteMessages(sequence, expunge: true);
      
      // Remove from local state with copy-on-write and update indexes
      final id = _messageKey(message);
      final mailboxKey = (id != null ? _messageIdToMailboxKey[id] : null);
      if (mailboxKey != null && _mailboxMessages.containsKey(mailboxKey)) {
        final list = _mailboxMessages[mailboxKey] ?? const <MimeMessage>[];
        final updated = list.where((m) => !((m.uid != null && m.uid == message.uid) || (m.sequenceId != null && m.sequenceId == message.sequenceId))).toList(growable: false);
        _mailboxMessages[mailboxKey] = updated;
        if (id != null) {
          _mailboxMessageIds[mailboxKey]?.remove(id);
          _messageIdToMailboxKey.remove(id);
        }
        // Update messages stream for INBOX if applicable
        if (mailboxKey.toUpperCase() == 'INBOX') {
          _messagesStream.add(updated);
        }
      }
      
      // Update streams
      _messageUpdateStream.add(MessageUpdate(
        message: message,
        type: MessageUpdateType.deleted,
      ));
      
    } catch (e) {
      _errorStream.add('Failed to delete message: $e');
    }
  }

  // Force refresh
  Future<void> forceRefresh() async {
    try {
      _syncStatusStream.add(SyncStatus.syncing);
      
      // Clear cache
      _cacheManager.clearCache();
      
      // Reload data
      await _loadInitialData();
      
    } catch (e) {
      _syncStatusStream.add(SyncStatus.error);
      _errorStream.add('Force refresh failed: $e');
    }
  }
}

// Enums and data classes
enum ConnectionStatus { connected, disconnected, connecting, error }
enum SyncStatus { idle, syncing, error }
enum MessageUpdateType {
  received,
  deleted,
  readStatusChanged,
  flagged,
  unflagged,
  statusChanged,
}
enum MailboxUpdateType { newMessages, messagesRemoved, statusChanged, messagesAdded }

class MessageUpdate {
  final MimeMessage message;
  final MessageUpdateType type;
  final Map<String, dynamic>? metadata;

  MessageUpdate({
    required this.message,
    required this.type,
    this.metadata,
  });
}

class MailboxUpdate {
  final Mailbox mailbox;
  final MailboxUpdateType type;
  final List<MimeMessage>? messages;
  final Map<String, dynamic>? metadata;

  MailboxUpdate({
    required this.mailbox,
    required this.type,
    this.messages,
    this.metadata,
  });
}

/// Extension to RealtimeUpdateService for incoming email notifications
extension IncomingEmailExtension on RealtimeUpdateService {
  /// Notify about new incoming messages. Optionally specify the mailbox the messages belong to.
  /// This avoids hard-coding to INBOX and keeps internal caches consistent.
  Future<void> notifyNewMessages(List<MimeMessage> newMessages, {Mailbox? mailbox}) async {
    try {
      RealtimeUpdateService._logger.i('📧 Processing ${newMessages.length} new messages');

      // Resolve mailbox key (default to currently selected or INBOX)
      String mailboxKey;
      if (mailbox != null) {
        mailboxKey = mailbox.path;
      } else {
        final mailService = _mailService;
        final selected = mailService?.client.selectedMailbox;
        mailboxKey = selected?.path ?? 'INBOX';
      }

      // Determine actual mailbox object to associate with these messages
      final mailService = _mailService;
      Mailbox? mb = mailbox ?? mailService?.client.selectedMailbox;
      final mbKey = mb?.path ?? mailboxKey;

      // Prepare existing state
      final existingList = _mailboxMessages[mbKey] ?? const <MimeMessage>[];
      final existingIds = _mailboxMessageIds.putIfAbsent(mbKey, () => <String>{});

      // Filter out duplicates and collect messages to prepend
      final List<MimeMessage> toPrepend = [];
      int unreadAdded = 0;
      for (final m in newMessages) {
        final id = _messageKey(m);
        if (id != null && existingIds.contains(id)) {
          continue; // skip duplicates
        }
        toPrepend.add(m);
        if (id != null) {
          existingIds.add(id);
          _messageIdToMailboxKey[id] = mbKey;
        }
        if (!m.isSeen) unreadAdded++;
      }

      if (toPrepend.isEmpty) {
        // Nothing new after de-dup
        return;
      }

      // Ensure envelope exists for toPrepend; fetch ENVELOPE for missing ones in a single batch when possible
      try {
        final mailService2 = _mailService;
        if (mailService2 != null) {
          final uidsNeedingEnv = <int>[];
          for (final m in toPrepend) {
            if (m.envelope == null && m.uid != null) {
              uidsNeedingEnv.add(m.uid!);
            }
          }
          if (uidsNeedingEnv.isNotEmpty) {
            try {
              // Select the actual mailbox if known; otherwise skip selection
              final selected = mb ?? mailService2.client.selectedMailbox ?? mailService2.client.mailboxes?.firstWhereOrNull((mm) => mm.path == mbKey);
              if (selected != null) {
                await mailService2.client.selectMailbox(selected);
              }
            } catch (_) {}
            try {
              final seq = MessageSequence.fromIds(uidsNeedingEnv);
              final fetched = await mailService2.client.fetchMessageSequence(
                seq,
                fetchPreference: FetchPreference.envelope,
              );
              final byUid = {for (final f in fetched) f.uid: f};
              for (var i = 0; i < toPrepend.length; i++) {
                final m = toPrepend[i];
                if (m.envelope == null && m.uid != null) {
                  final rep = byUid[m.uid];
                  if (rep != null) {
                    // Replace with the fetched message that includes envelope
                    toPrepend[i] = rep;
                  }
                }
              }
            } catch (_) {}
          }
        }
      } catch (_) {}

      // Prepend new messages (keep order as received)
      final updated = [...toPrepend, ...existingList];
      _mailboxMessages[mbKey] = updated;

      // Update unread counts only for actually added messages
      _unreadCounts[mbKey] = (_unreadCounts[mbKey] ?? 0) + unreadAdded;

      // Emit mailbox update event (use the real mailbox when available)
      if (mb != null) {
        _mailboxUpdateStream.add(MailboxUpdate(
          mailbox: mb,
          type: MailboxUpdateType.messagesAdded,
          messages: toPrepend,
          metadata: {'unreadCount': _unreadCounts[mbKey] ?? 0},
        ));
      } else {
        // Fallback minimal event without real mailbox
        _mailboxUpdateStream.add(MailboxUpdate(
          mailbox: Mailbox(
            encodedName: mbKey,
            encodedPath: mbKey,
            flags: const [],
            pathSeparator: '/',
          )..name = mbKey,
          type: MailboxUpdateType.messagesAdded,
          messages: toPrepend,
          metadata: {'unreadCount': _unreadCounts[mbKey] ?? 0},
        ));
      }

      // Emit individual message events
      for (final m in toPrepend) {
        _messageUpdateStream.add(MessageUpdate(
          message: m,
          type: MessageUpdateType.received,
          metadata: {'mailboxName': mbKey},
        ));
      }

      // Update reactive streams (only push to messages stream for INBOX to reduce noise)
      if (mb?.isInbox == true || mbKey.toUpperCase() == 'INBOX') {
        _messagesStream.add(updated);
      }
      _unreadCountsStream.add(Map.from(_unreadCounts));

      // Fast-path: prefetch details for a few newest messages and fire notifications with previews
      try {
        if (mb != null && toPrepend.isNotEmpty) {
          // Prefetch 1-3 messages to make subject/attachments/preview available quickly
          unawaited(_prefetchNewMessageDetailsAndNotify(mb, toPrepend.take(3).toList()));
        }
      } catch (_) {}

      RealtimeUpdateService._logger.i('📧 Successfully processed ${toPrepend.length} new messages (de-duplicated)');

    } catch (e) {
      RealtimeUpdateService._logger.e('📧 Error processing new messages: $e');
      _errorStream.add('Failed to process new messages: $e');
    }
  }

  /// Fetch new messages for the currently selected (or specified) mailbox and notify listeners.
  /// This is used by the optimized IDLE/polling service to actually load server-side changes.
  Future<void> fetchAndNotifyNewMessages({Mailbox? mailbox}) async {
    try {
      final mailService = _mailService;
      if (mailService == null) return;
      if (!mailService.client.isConnected) {
        await mailService.connect();
      }

      // Resolve mailbox
      Mailbox? mb = mailbox ?? mailService.client.selectedMailbox;
      mb ??= mailService.client.mailboxes?.firstWhereOrNull((m) => m.isInbox);
      if (mb == null) return;

      // Ensure mailbox is selected
      await mailService.client.selectMailbox(mb);

      final key = mb.path;
      // Concurrency guard for this mailbox
      if (_fetchInProgress[key] == true) return;
      _fetchInProgress[key] = true;

      try {
        // Use UIDNEXT to determine the new range and avoid treating history as new
        final uidNext = mb.uidNext;
        if (uidNext == null || uidNext <= 1) {
          return; // can't determine
        }
        final endUid = uidNext - 1;
        final last = _lastNotifiedUid[key];

        // First-run baseline: do not notify historical messages
        if (last == null) {
          _lastNotifiedUid[key] = endUid;
          return;
        }

        // Nothing new
        if (endUid <= last) {
          return;
        }

        int startUid = last + 1;
        // Safety cap to avoid massive UI spikes; still advance baseline
        const int maxBatch = 50;
        final totalNew = endUid - startUid + 1;
        if (totalNew > maxBatch) {
          startUid = endUid - maxBatch + 1;
        }

        // Fetch only the new UID range, envelope-only for speed
        final seq = MessageSequence.fromRange(startUid, endUid, isUidSequence: true);
        final fetched = await mailService.client.fetchMessageSequence(
          seq,
          fetchPreference: FetchPreference.envelope,
        );

        if (fetched.isNotEmpty) {
          await notifyNewMessages(fetched, mailbox: mb);
        }

        // Advance baseline to current end, regardless of batch size
        _lastNotifiedUid[key] = endUid;
      } finally {
        _fetchInProgress[key] = false;
      }

    } catch (e) {
      if (kDebugMode) {
        print('📧 Error fetching and notifying new messages: $e');
      }
      _errorStream.add('Failed to fetch new messages: $e');
    }
  }
}

extension _RealtimeFastPath on RealtimeUpdateService {
  Future<void> _prefetchNewMessageDetailsAndNotify(Mailbox mailbox, List<MimeMessage> messages) async {
    try {
      final mailService = _mailService;
      if (mailService == null || messages.isEmpty) return;
      // Ensure mailbox selected once
      try {
        if (!mailService.client.isConnected) await mailService.connect();
        await mailService.client.selectMailbox(mailbox);
      } catch (_) {}

      for (final m in messages) {
        try {
          // Fetch full if within size for attachments/preview
          MessageSequence seq;
          if (m.uid != null) {
            seq = MessageSequence.fromRange(m.uid!, m.uid!, isUidSequence: true);
          } else {
            seq = MessageSequence.fromMessage(m);
          }
          final fetched = await mailService.client.fetchMessageSequence(
            seq,
            fetchPreference: FetchPreference.fullWhenWithinSize,
          );
          if (fetched.isEmpty) continue;
          final full = fetched.first;

          // Compute preview
          String preview = '';
          try {
            final plain = full.decodeTextPlainPart();
            if (plain != null && plain.isNotEmpty) {
              preview = plain.replaceAll(RegExp(r'\s+'), ' ').trim();
            } else {
              final html = full.decodeTextHtmlPart();
              if (html != null && html.isNotEmpty) {
                final stripped = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
                preview = stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
              }
            }
            if (preview.length > 140) preview = preview.substring(0, 140);
          } catch (_) {}

          bool hasAtt = false;
          try { hasAtt = full.hasAttachments(); } catch (_) {}

          // Update internal list with full version (copy-on-write)
          final key = mailbox.path;
          final list = _mailboxMessages[key] ?? const <MimeMessage>[];
          int idx = list.indexWhere((mm) =>
              (full.uid != null && mm.uid == full.uid) ||
              (full.sequenceId != null && mm.sequenceId == full.sequenceId));
          List<MimeMessage> updated;
          if (idx >= 0) {
            updated = List<MimeMessage>.from(list);
            updated[idx] = full;
          } else {
            updated = [full, ...list];
          }
          _mailboxMessages[key] = updated;

          // Stamp headers (both full and original placeholder if still referenced)
          try { full.setHeader('x-preview', preview); } catch (_) {}
          try { m.setHeader('x-preview', preview); } catch (_) {}
          try { full.setHeader('x-has-attachments', hasAtt ? '1' : '0'); } catch (_) {}
          try { m.setHeader('x-has-attachments', hasAtt ? '1' : '0'); } catch (_) {}
          try { full.setHeader('x-ready', '1'); } catch (_) {}
          try { m.setHeader('x-ready', '1'); } catch (_) {}

          // Emit a status-changed update to refresh UI tiles immediately
          _messageUpdateStream.add(MessageUpdate(
            message: full,
            type: MessageUpdateType.statusChanged,
            metadata: {'mailboxName': key},
          ));
          if (mailbox.isInbox) {
            _messagesStream.add(updated);
          }

          // Fire local notification with preview
          try {
            final from = full.from != null && full.from!.isNotEmpty
                ? (full.from!.first.personalName ?? full.from!.first.email)
                : 'New Email';
            final subject = full.decodeSubject() ?? 'No Subject';
            final notifBody = preview.isNotEmpty ? '$subject — $preview' : subject;
            NotificationService.instance.showFlutterNotification(
              from,
              notifBody,
              {
                'action': 'view_message',
                'message_uid': full.uid?.toString() ?? '',
                'mailbox': mailbox.path,
                'preview': preview,
              },
              full.uid?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
            );
          } catch (_) {}
        } catch (_) {
          // ignore per-message failure
        }
      }
    } catch (_) {}
  }
}
