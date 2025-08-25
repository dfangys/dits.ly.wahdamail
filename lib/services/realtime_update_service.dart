import 'dart:async';
import 'dart:collection';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:rxdart/rxdart.dart';

import 'cache_manager.dart';
import 'mail_service.dart';

/// Real-time update service for reactive UI updates
class RealtimeUpdateService extends GetxService {
  static RealtimeUpdateService get instance => Get.find<RealtimeUpdateService>();

  final MailService _mailService = Get.find<MailService>();
  final CacheManager _cacheManager = CacheManager.instance;

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
      
      // Load mailboxes
      if (_mailService.client.isConnected) {
        final mailboxes = await _mailService.client.listMailboxes();
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
      if (_mailService.client.isConnected) {
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
      _connectionStatusStream.add(ConnectionStatus.connecting);
      await _mailService.connect();
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
      if (!_mailService.client.isConnected) {
        await _mailService.connect();
      }
      
      await _mailService.client.selectMailbox(mailbox);
      
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
      final newMessageCount = mailbox.messagesExists - currentCount;
      if (newMessageCount <= 0) return;
      
      // Fetch new messages
      final sequence = MessageSequence.fromRange(
        mailbox.messagesExists - newMessageCount + 1,
        mailbox.messagesExists,
      );
      
      final newMessages = await _mailService.client.fetchMessages(
        mailbox: mailbox,
        count: newMessageCount,
        page: 1,
      );
      
      // Update cache and streams
      final existingMessages = _mailboxMessages[mailbox.path] ?? [];
      final updatedMessages = [...existingMessages, ...newMessages];
      _mailboxMessages[mailbox.path] = updatedMessages;
      
      // Cache new messages
      for (final message in newMessages) {
        _cacheManager.cacheMessage(message);
      }
      
      // Emit updates
      if (mailbox.isInbox) {
        _messagesStream.add(updatedMessages);
      }
      
      _mailboxUpdateStream.add(MailboxUpdate(
        mailbox: mailbox,
        type: MailboxUpdateType.newMessages,
        messages: newMessages,
      ));
      
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
      
      if (!_mailService.client.isConnected) {
        await _mailService.connect();
      }
      
      await _mailService.client.selectMailbox(mailbox);
      
      // Load messages in batches
      const batchSize = 20;
      final totalMessages = mailbox.messagesExists;
      final messages = <MimeMessage>[];
      
      for (int i = 0; i < totalMessages; i += batchSize) {
        final end = (i + batchSize > totalMessages) ? totalMessages : i + batchSize;
        final count = end - i;
        final page = (i ~/ batchSize) + 1;
        
        final batchMessages = await _mailService.client.fetchMessages(
          mailbox: mailbox,
          count: count,
          page: page,
        );
        messages.addAll(batchMessages);
        
        // Cache messages
        for (final message in batchMessages) {
          _cacheManager.cacheMessage(message);
        }
      }
      
      _mailboxMessages[mailbox.path] = messages;
      
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
      final sequence = MessageSequence.fromMessage(message);
      await _mailService.client.markSeen(sequence);
      
      // Update local state
      message.isSeen = true;
      
      // Update streams
      _messageUpdateStream.add(MessageUpdate(
        message: message,
        type: MessageUpdateType.statusChanged,
      ));
      
      // Update unread counts
      for (final mailboxPath in _mailboxMessages.keys) {
        await _updateUnreadCount(Mailbox(
          encodedName: '',
          encodedPath: mailboxPath,
          flags: [],
          pathSeparator: '/',
        ));
      }
      
    } catch (e) {
      _errorStream.add('Failed to mark message as read: $e');
    }
  }

  Future<void> markMessageAsUnread(MimeMessage message) async {
    try {
      final sequence = MessageSequence.fromMessage(message);
      await _mailService.client.markUnseen(sequence);
      
      // Update local state
      message.isSeen = false;
      
      // Update streams
      _messageUpdateStream.add(MessageUpdate(
        message: message,
        type: MessageUpdateType.statusChanged,
      ));
      
      // Update unread counts
      for (final mailboxPath in _mailboxMessages.keys) {
        await _updateUnreadCount(Mailbox(
          encodedName: '',
          encodedPath: mailboxPath,
          flags: [],
          pathSeparator: '/',
        ));
      }
      
    } catch (e) {
      _errorStream.add('Failed to mark message as unread: $e');
    }
  }

  Future<void> flagMessage(MimeMessage message) async {
    try {
      final sequence = MessageSequence.fromMessage(message);
      await _mailService.client.markFlagged(sequence);
      
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
      final sequence = MessageSequence.fromMessage(message);
      await _mailService.client.markUnflagged(sequence);
      
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
      final sequence = MessageSequence.fromMessage(message);
      await _mailService.client.deleteMessages(sequence, expunge: true);
      
      // Remove from local state
      for (final messages in _mailboxMessages.values) {
        messages.removeWhere((m) => 
          (m.uid != null && m.uid == message.uid) ||
          (m.sequenceId != null && m.sequenceId == message.sequenceId)
        );
      }
      
      // Update streams
      _messageUpdateStream.add(MessageUpdate(
        message: message,
        type: MessageUpdateType.deleted,
      ));
      
      // Refresh current messages
      _messagesStream.add(List.from(_messagesStream.value));
      
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
enum MessageUpdateType { statusChanged, deleted, moved }
enum MailboxUpdateType { newMessages, messagesRemoved, statusChanged }

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

