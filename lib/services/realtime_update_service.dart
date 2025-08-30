import 'dart:async';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:rxdart/rxdart.dart';
import 'package:logger/logger.dart';

import 'cache_manager.dart';
import 'mail_service.dart';
import 'imap_command_queue.dart';
import 'imap_fetch_pool.dart';

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
      
      await ImapCommandQueue.instance.run('selectMailbox(syncMailbox:${mailbox.name})', () async {
        await mailService.client.selectMailbox(mailbox);
      });
      
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
      
      // Ensure the correct mailbox is selected to avoid server errors
      try {
        if (mailService.client.selectedMailbox?.encodedPath != mailbox.encodedPath) {
          await ImapCommandQueue.instance.run('selectMailbox(loadNewMessages:${mailbox.name})', () async {
            await mailService.client.selectMailbox(mailbox).timeout(const Duration(seconds: 8));
          });
        }
      } catch (_) {}

      // Fetch new messages
      final newMessages = await ImapCommandQueue.instance.run('fetchMessages(loadNewMessages:${mailbox.name})', () async {
        return await mailService.client.fetchMessages(
          mailbox: mailbox,
          count: newMessageCount,
          page: 1,
        );
      });
      
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
        type: MailboxUpdateType.messagesAdded,
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
      
      final mailService = _mailService;
      if (mailService == null) {
        _syncStatusStream.add(SyncStatus.error);
        _errorStream.add('MailService not available for loading mailbox messages');
        return;
      }
      
      if (!mailService.client.isConnected) {
        await mailService.connect();
      }
      
      await ImapCommandQueue.instance.run('selectMailbox(loadMailboxMessages:${mailbox.name})', () async {
        await mailService.client.selectMailbox(mailbox);
      });
      
      // Load messages in batches
      const batchSize = 20;
      final totalMessages = mailbox.messagesExists;
      final messages = <MimeMessage>[];
      
      for (int i = 0; i < totalMessages; i += batchSize) {
        final end = (i + batchSize > totalMessages) ? totalMessages : i + batchSize;
        final count = end - i;
        final page = (i ~/ batchSize) + 1;
        
        final batchMessages = await ImapCommandQueue.instance.run('fetchMessages(batch:${mailbox.name}:p$page:c$count)', () async {
          return await mailService.client.fetchMessages(
            mailbox: mailbox,
            count: count,
            page: page,
          );
        });
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
      await ImapCommandQueue.instance.run('markSeen', () async {
        await mailService.client.markSeen(sequence);
      });
      
      if (kDebugMode) {
        print('📧 Successfully marked message as read on server');
      }
      
      // Update local state only after server success
      message.isSeen = true;
      
      // Update unread counts
      final mailboxKey = mailService.client.selectedMailbox?.name ?? 'INBOX';
      if (_unreadCounts[mailboxKey] != null && _unreadCounts[mailboxKey]! > 0) {
        _unreadCounts[mailboxKey] = _unreadCounts[mailboxKey]! - 1;
        _unreadCountsStream.add(Map.from(_unreadCounts));
      }
      
      // Update streams
      _messageUpdateStream.add(MessageUpdate(
        message: message,
        type: MessageUpdateType.statusChanged,
      ));
      
      // Refresh messages stream
      _messagesStream.add(_mailboxMessages.values.expand((msgs) => msgs).toList());
      
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
      await ImapCommandQueue.instance.run('markUnseen', () async {
        await mailService.client.markUnseen(sequence);
      });
      
      if (kDebugMode) {
        print('📧 Successfully marked message as unread on server');
      }
      
      // Update local state only after server success
      message.isSeen = false;
      
      // Update unread counts
      final mailboxKey = mailService.client.selectedMailbox?.name ?? 'INBOX';
      _unreadCounts[mailboxKey] = (_unreadCounts[mailboxKey] ?? 0) + 1;
      _unreadCountsStream.add(Map.from(_unreadCounts));
      
      // Update streams
      _messageUpdateStream.add(MessageUpdate(
        message: message,
        type: MessageUpdateType.statusChanged,
      ));
      
      // Refresh messages stream
      _messagesStream.add(_mailboxMessages.values.expand((msgs) => msgs).toList());
      
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
      await ImapCommandQueue.instance.run('markFlagged', () async {
        await mailService.client.markFlagged(sequence);
      });
      
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
      await ImapCommandQueue.instance.run('markUnflagged', () async {
        await mailService.client.markUnflagged(sequence);
      });
      
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
      await ImapCommandQueue.instance.run('deleteMessages(expunge:true)', () async {
        await mailService.client.deleteMessages(sequence, expunge: true);
      });
      
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
  /// Notify about new incoming messages
  /// ENHANCED: Notify about new messages with event-driven architecture
  Future<void> notifyNewMessages(List<MimeMessage> newMessages, {Mailbox? mailbox}) async {
    try {
      // If called with no concrete messages (e.g., from IDLE signal), perform a quick incremental sync
      if (newMessages.isEmpty && mailbox != null) {
        try {
          final existing = _mailboxMessages[mailbox.path]?.length ?? 0;
          await _loadNewMessages(mailbox, existing);
        } catch (_) {}
        return;
      }

      RealtimeUpdateService._logger.i('📧 Processing ${newMessages.length} new messages');

      // Determine target mailbox early for hydration fetches
      final String targetMailboxKey = (mailbox != null && mailbox.name.isNotEmpty)
          ? mailbox.name
          : ((mailbox != null && mailbox.encodedName.isNotEmpty) ? mailbox.encodedName : 'INBOX');
      final Mailbox targetMailbox = mailbox ?? (Mailbox(
        encodedName: targetMailboxKey,
        encodedPath: targetMailboxKey,
        flags: [],
        pathSeparator: '/',
      )..name = targetMailboxKey);

      // Best-effort: quickly hydrate missing envelope for sparse events before emitting
      try {
        final toFetch = <MimeMessage>[];
        for (final m in newMessages) {
          bool hasSender = (m.from?.isNotEmpty ?? false) || (m.envelope?.from?.isNotEmpty ?? false);
          bool hasSubject = false;
          try {
            final s1 = m.decodeSubject();
            hasSubject = (s1 != null && s1.trim().isNotEmpty) || ((m.envelope?.subject ?? '').trim().isNotEmpty);
          } catch (_) {
            hasSubject = (m.envelope?.subject ?? '').trim().isNotEmpty;
          }
          if (!(hasSender && hasSubject)) {
            // Only attempt fetch if we have an identifier
            if (m.uid != null || m.sequenceId != null) {
              toFetch.add(m);
            }
          }
        }
        if (toFetch.isNotEmpty) {
          final mailService = _mailService;
          if (mailService != null) {
            try {
              if (!mailService.client.isConnected) {
                await mailService.connect().timeout(const Duration(seconds: 6));
              }
            } catch (_) {}
            try {
              if (mailService.client.selectedMailbox?.encodedPath != targetMailbox.encodedPath) {
                await ImapCommandQueue.instance.run('selectMailbox(rt:env:${targetMailbox.name})', () async {
                  await mailService.client.selectMailbox(targetMailbox).timeout(const Duration(seconds: 6));
                });
              }
            } catch (_) {}

            // Limit to a few quick fetches to reduce latency
            final fetchList = toFetch.take(4).toList();
            for (final base in fetchList) {
              try {
                final fetched = await ImapFetchPool.instance.fetchForMessage(
                  base: base,
                  mailboxHint: targetMailbox,
                  fetchPreference: FetchPreference.envelope,
                  timeout: const Duration(seconds: 4),
                );
                if (fetched.isNotEmpty) {
                  final env = fetched.first.envelope;
                  if (env != null) {
                    base.envelope = env;
                    if ((base.from == null || base.from!.isEmpty) && (env.from?.isNotEmpty ?? false)) {
                      base.from = env.from;
                    }
                  }
                }
              } catch (_) {}
            }
          }
        }
      } catch (_) {}

      // Ensure tiles can render immediately and hydrate minimal sender/subject
      for (final m in newMessages) {
        try {
          // Hydrate top-level from if missing
          if ((m.from == null || m.from!.isEmpty) && (m.envelope?.from?.isNotEmpty ?? false)) {
            m.from = m.envelope!.from;
          }
          // Normalize subject using decode/envelope, then raw header fallback
          String? subj = m.decodeSubject();
          subj ??= m.envelope?.subject;
          if (subj == null || subj.trim().isEmpty) {
            final hdr = m.getHeaderValue('subject');
            if (hdr != null && hdr.trim().isNotEmpty) {
              subj = hdr.trim();
              try { m.setHeader('subject', subj); } catch (_) {}
              if (kDebugMode) {
                print('📧 RT fallback: subject via raw header: $subj');
              }
            }
          }
          // Sender fallback: raw From header when envelope/from missing
          if (m.from == null || m.from!.isEmpty) {
            final rawFrom = m.getHeaderValue('from');
            if (rawFrom != null && rawFrom.trim().isNotEmpty) {
              // Minimal parse: keep raw text as address; avoid using APIs that may be unavailable
              try { m.setHeader('from', rawFrom.trim()); } catch (_) {}
              m.from = [MailAddress('', rawFrom.trim())];
              if (kDebugMode) {
                print('📧 RT fallback: sender via raw header');
              }
            }
          }
          // If still no envelope but we have any sender/subject, synthesize a minimal envelope
          if (m.envelope == null && ((m.from?.isNotEmpty ?? false) || (subj != null && subj.trim().isNotEmpty))) {
            try {
              m.envelope = Envelope(
                date: m.decodeDate() ?? DateTime.now(),
                subject: subj,
                from: m.from,
              );
              if (kDebugMode) {
                print('📧 RT fallback: synthesized minimal envelope for immediate tile hydration');
              }
            } catch (_) {}
          }
          // Mark ready so tiles avoid shimmer when metadata is present
          if ((m.getHeaderValue('x-ready') ?? '') != '1') {
            m.setHeader('x-ready', '1');
          }
        } catch (_) {}
      }
      
      // Batch process messages for performance
      final Map<String, List<MimeMessage>> messagesByMailbox = {};
      final Map<String, int> unreadCountChanges = {};
      
      for (final message in newMessages) {
        // Determine target mailbox (usually INBOX for new messages)
        final mailboxKey = targetMailboxKey;

        // Ensure storage slot
        _mailboxMessages.putIfAbsent(mailboxKey, () => <MimeMessage>[]);
        final listRef = _mailboxMessages[mailboxKey]!;

        // Dedupe by UID or sequenceId and merge if exists
        int existingIndex = -1;
        try {
          existingIndex = listRef.indexWhere((m) =>
              (message.uid != null && m.uid == message.uid) ||
              (message.sequenceId != null && m.sequenceId == message.sequenceId));
        } catch (_) {}

        if (existingIndex >= 0) {
          // Merge minimal fields to update tile immediately without flicker
          final existing = listRef[existingIndex];
          try {
            if (message.envelope != null) existing.envelope = message.envelope;
            if ((existing.from == null || existing.from!.isEmpty) && (message.from?.isNotEmpty ?? false)) {
              existing.from = message.from;
            }
            // Carry over ready/preview/attachments hints
            final pv = message.getHeaderValue('x-preview');
            if (pv != null && pv.trim().isNotEmpty) existing.setHeader('x-preview', pv);
            if ((message.getHeaderValue('x-ready') ?? '') == '1') existing.setHeader('x-ready', '1');
            final att = message.getHeaderValue('x-has-attachments');
            if (att != null) existing.setHeader('x-has-attachments', att);
            // Flags consistency
            existing.isSeen = existing.isSeen || message.isSeen;
            existing.isFlagged = existing.isFlagged || message.isFlagged;
          } catch (_) {}

          // Emit a statusChanged to refresh UI bindings
          _messageUpdateStream.add(MessageUpdate(
            message: existing,
            type: MessageUpdateType.statusChanged,
            metadata: {'mailboxName': mailboxKey},
          ));
          continue; // Do not add as a new message
        }

        // Group truly new messages by mailbox for batch processing
        messagesByMailbox.putIfAbsent(mailboxKey, () => []).add(message);

        // Track unread count changes
        if (!message.isSeen) {
          unreadCountChanges[mailboxKey] = (unreadCountChanges[mailboxKey] ?? 0) + 1;
        }

        // Insert new message at top
        listRef.insert(0, message);
      }
      
      // Batch update unread counts
      for (final entry in unreadCountChanges.entries) {
        _unreadCounts[entry.key] = (_unreadCounts[entry.key] ?? 0) + entry.value;
      }
      
      // Emit batched updates for better performance
      for (final entry in messagesByMailbox.entries) {
        final mailboxKey = entry.key;
        final messages = entry.value;
        
        // Emit mailbox update event using the correct type expected by UI
        _mailboxUpdateStream.add(MailboxUpdate(
          mailbox: targetMailbox,
          type: MailboxUpdateType.messagesAdded,
          messages: messages,
          metadata: {'unreadCount': _unreadCounts[mailboxKey] ?? 0},
        ));
        
        // Emit individual message events for UI reactivity
        for (final message in messages) {
          _messageUpdateStream.add(MessageUpdate(
            message: message,
            type: MessageUpdateType.received,
            metadata: {'mailboxName': mailboxKey},
          ));
        }
      }
      
      // Update reactive streams (default to target mailbox list)
      _messagesStream.add(_mailboxMessages[targetMailboxKey] ?? []);
      _unreadCountsStream.add(Map.from(_unreadCounts));
      
      RealtimeUpdateService._logger.i('📧 Successfully processed ${newMessages.length} new messages');
      
    } catch (e) {
      RealtimeUpdateService._logger.e('📧 Error processing new messages: $e');
      _errorStream.add('Failed to process new messages: $e');
    }
  }
}

