import 'dart:async';
import 'dart:collection';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wahda_bank/app/controllers/mail_count_controller.dart';
import 'package:wahda_bank/models/sqlite_mime_storage.dart';

/// A mime storage using SQLite as its backend with reactive updates
///
/// This class provides a SQLite-based implementation of the offline MIME storage
/// with optimized loading, caching, and reactive updates to prevent UI blocking.
class SqliteMailboxStorage {
  SqliteMailboxStorage({
    required MailAccount mailAccount,
    required Mailbox mailbox,
  })  : _mailAccount = mailAccount,
        _mailbox = mailbox;

  final MailAccount _mailAccount;
  final Mailbox _mailbox;
  final SqliteMimeStorage _sqliteStorage = SqliteMimeStorage.instance;
  final List<StorageMessageId> _allMessageIds = <StorageMessageId>[];
  final RxList<MimeMessage> _messages = <MimeMessage>[].obs;

  // Enhanced LRU cache with size limit
  final _messageCache = _LRUCache<int, MimeMessage>(500);

  // Stream controller for message changes with BehaviorSubject for better state management
  final _messageSubject = BehaviorSubject<List<MimeMessage>>();
  Stream<List<MimeMessage>> get messageStream => _messageSubject.stream;

  // For compatibility with the previous ValueListenable pattern
  late _MessageListenable dataStream;

  // Loading state
  final RxBool _isLoading = false.obs;
  bool get isLoading => _isLoading.value;

  // Track last fetched UID for incremental updates
  int _lastFetchedUid = 0;

  // Track last refresh time for cache invalidation
  DateTime _lastRefreshed = DateTime.now();
  DateTime get lastRefreshed => _lastRefreshed;

  // Batch operation lock
  final _batchLock = Object();

  // Transaction lock to prevent concurrent database operations
  late var _transactionLock = Completer<void>();
  bool _isTransactionLockAcquired = false;

  // Debounce timer for UI updates
  Timer? _debounceTimer;

  Logger get logger => Logger();

  /// Initialize the storage with optimized loading
  Future<void> init() async {
    // Initialize the SQLite storage if needed
    await _sqliteStorage.database;

    // Release transaction lock to allow operations
    if (!_isTransactionLockAcquired) {
      _transactionLock.complete();
      _isTransactionLockAcquired = true;
    }

    // Set up the listenable for compatibility
    dataStream = _MessageListenable(_messages);

    // Set up listener for unread count updates
    _messages.listen((messages) {
      int count = messages.where((e) => !e.isSeen).length;
      if (Get.isRegistered<MailCountController>()) {
        Get.find<MailCountController>()
            .setCount("${_mailbox.name.toLowerCase()}_count", count);
      }
    });

    // Subscribe to SQLite storage message updates
    _sqliteStorage.messageUpdateStream.listen((update) {
      // Only process updates for this mailbox
      if (update.accountId == _mailAccount.email &&
          update.mailboxPath == _mailbox.encodedPath) {

        if (update.type case MessageUpdateType.update) {
          _handleMessageUpdate(update.messages);
        } else if (update.type case MessageUpdateType.delete) {
          _handleMessageDelete(update.messages);
        } else if (update.type case MessageUpdateType.flagUpdate) {
          _handleMessageFlagUpdate(update.messages);
        } else if (update.type case MessageUpdateType.clear) {
          _handleMailboxClear();
        }
      }
    });

    // Initialize the message subject with empty list
    if (!_messageSubject.hasValue) {
      _messageSubject.add([]);
    }

    // Load message IDs in background to prevent UI blocking
    _loadMessageIdsAsync();
  }

  /// Acquire transaction lock to prevent concurrent database operations
  Future<void> _acquireTransactionLock() async {
    if (_isTransactionLockAcquired) {
      // Lock is already acquired and completed, create a new one
      _transactionLock = Completer<void>();
      _isTransactionLockAcquired = false;
    }

    if (!_isTransactionLockAcquired) {
      await _transactionLock.future;
      _isTransactionLockAcquired = true;
    }
  }

  /// Release transaction lock
  void _releaseTransactionLock() {
    if (!_isTransactionLockAcquired) {
      _transactionLock.complete();
      _isTransactionLockAcquired = true;
    }
  }

  /// Load message IDs asynchronously to prevent UI blocking
  Future<void> _loadMessageIdsAsync() async {
    _isLoading.value = true;

    try {
      await _acquireTransactionLock();

      final db = await _sqliteStorage.database;

      // Use a transaction for better performance
      await db.transaction((txn) async {
        final List<Map<String, dynamic>> maps = await txn.query(
          'messages',
          columns: ['id', 'sequence_id', 'uid'],
          where: 'account_id = ? AND mailbox_path = ?',
          whereArgs: [_mailAccount.email, _mailbox.encodedPath],
          orderBy: 'date DESC', // Pre-sort by date for faster loading
        );

        _allMessageIds.clear();
        for (final map in maps) {
          final sequenceId = map['sequence_id'] as int;
          final uid = map['uid'] as int;
          final guid = _generateGuid(uid);

          // Track highest UID for incremental fetching
          if (uid > _lastFetchedUid) {
            _lastFetchedUid = uid;
          }

          _allMessageIds.add(StorageMessageId(
            sequenceId: sequenceId,
            uid: uid,
            guid: guid,
          ));
        }
      });

      // Update last refresh time
      _lastRefreshed = DateTime.now();

      // Pre-load first page of messages to improve perceived performance
      if (_allMessageIds.isNotEmpty) {
        final firstPageIds = _allMessageIds.take(20).toList();
        final messages = await _loadMessagesFromIds(firstPageIds);
        if (messages.isNotEmpty) {
          _messages.assignAll(messages);

          // Update the message subject
          _notifyListeners();
        }
      }
    } catch (e) {
      logger.e('Error loading message IDs: $e');
    } finally {
      _releaseTransactionLock();
      _isLoading.value = false;
    }
  }

  /// Generate a GUID from a UID for compatibility
  int _generateGuid(int uid) {
    // Simple hash function to generate a GUID from mailbox path and UID
    return (_mailbox.encodedPath.hashCode ^ uid.hashCode).abs();
  }

  /// Load messages from a list of IDs with batching for better performance
  Future<List<MimeMessage>> _loadMessagesFromIds(List<StorageMessageId> ids) async {
    if (ids.isEmpty) return [];

    final messages = <MimeMessage>[];

    try {
      await _acquireTransactionLock();

      final db = await _sqliteStorage.database;

      // Process in smaller batches to prevent UI blocking
      const batchSize = 20;
      for (var i = 0; i < ids.length; i += batchSize) {
        final end = (i + batchSize < ids.length) ? i + batchSize : ids.length;
        final batch = ids.sublist(i, end);

        // Build query with IN clause for better performance
        final placeholders = List.filled(batch.length, '?').join(',');
        final uids = batch.map((id) => id.uid).toList();

        final List<Map<String, dynamic>> maps = await db.query(
          'messages',
          where: 'account_id = ? AND mailbox_path = ? AND uid IN ($placeholders)',
          whereArgs: [_mailAccount.email, _mailbox.encodedPath, ...uids],
        );

        for (final map in maps) {
          final message = _mapToMimeMessage(map);
          if (message != null) {
            // Add to cache for faster retrieval
            _messageCache.put(message.uid!, message);
            messages.add(message);
          }
        }

        // Yield to UI thread to prevent blocking
        await Future.delayed(Duration.zero);
      }
    } catch (e) {
      logger.e('Error loading messages from IDs: $e');
    } finally {
      _releaseTransactionLock();
    }

    return messages;
  }

  /// Get only new messages since last fetch
  Future<List<MimeMessage>?> loadNewMessages(int lastUid) async {
    logger.d('Loading new messages since UID $lastUid for ${_mailAccount.name}');

    if (_isLoading.value) {
      return null;
    }

    _isLoading.value = true;

    try {
      await _acquireTransactionLock();

      final db = await _sqliteStorage.database;

      final List<Map<String, dynamic>> maps = await db.query(
        'messages',
        where: 'account_id = ? AND mailbox_path = ? AND uid > ?',
        whereArgs: [_mailAccount.email, _mailbox.encodedPath, lastUid],
        orderBy: 'date DESC',
      );

      final newMessages = <MimeMessage>[];

      for (final map in maps) {
        final message = _mapToMimeMessage(map);
        if (message != null) {
          // Add to cache for faster retrieval
          _messageCache.put(message.uid!, message);
          newMessages.add(message);

          // Update _allMessageIds
          final uid = message.uid!;
          final guid = _generateGuid(uid);

          if (!_allMessageIds.any((id) => id.uid == uid)) {
            _allMessageIds.add(StorageMessageId(
              sequenceId: message.sequenceId ?? 0,
              uid: uid,
              guid: guid,
            ));
          }

          // Update last fetched UID
          if (uid > _lastFetchedUid) {
            _lastFetchedUid = uid;
          }
        }
      }

      // Update last refresh time
      _lastRefreshed = DateTime.now();

      if (newMessages.isNotEmpty) {
        // Merge with existing messages
        final updatedMessages = List<MimeMessage>.from(_messages);
        updatedMessages.addAll(newMessages);

        // Sort by date
        updatedMessages.sort((a, b) {
          final dateA = a.decodeDate() ?? DateTime.now();
          final dateB = b.decodeDate() ?? DateTime.now();
          return dateB.compareTo(dateA);
        });

        _messages.assignAll(updatedMessages);

        // Update the message subject
        _notifyListeners();
      }

      return newMessages;
    } catch (e) {
      logger.e('Error loading new messages: $e');
      return null;
    } finally {
      _releaseTransactionLock();
      _isLoading.value = false;
    }
  }

  /// Load message envelopes from storage with optimized loading
  Future<List<MimeMessage>?> loadMessageEnvelopes(
      MessageSequence sequence,
      ) async {
    logger.d('Load offline messages for ${_mailAccount.name}');

    // If already loading, return current messages to prevent duplicate loading
    if (_isLoading.value) {
      return _messages;
    }

    _isLoading.value = true;

    try {
      await _acquireTransactionLock();

      final ids = sequence.toList(_mailbox.messagesExists);
      if (_allMessageIds.length < ids.length) {
        logger.d('${_mailAccount.name}: not enough ids (${_allMessageIds.length})');
        return null;
      }

      final envelopes = <MimeMessage>[];
      final isUid = sequence.isUidSequence;

      // Process in smaller batches to prevent UI blocking
      const batchSize = 20;
      for (var i = 0; i < ids.length; i += batchSize) {
        final end = (i + batchSize < ids.length) ? i + batchSize : ids.length;
        final batchIds = ids.sublist(i, end);

        for (final id in batchIds) {
          final messageId = _allMessageIds.firstWhereOrNull((messageId) =>
          isUid ? messageId.uid == id : messageId.sequenceId == id);

          if (messageId == null) {
            logger.d(
              '${_mailAccount.name}: ${isUid ? 'uid' : 'sequence-id'}'
                  ' $id not found in allIds',
            );
            continue;
          }

          // Check cache first for better performance
          final cachedMessage = _messageCache.get(messageId.uid);
          if (cachedMessage != null) {
            envelopes.add(cachedMessage);
            continue;
          }

          // Query the message from SQLite
          final db = await _sqliteStorage.database;
          final List<Map<String, dynamic>> maps = await db.query(
            'messages',
            where: 'account_id = ? AND mailbox_path = ? AND uid = ?',
            whereArgs: [_mailAccount.email, _mailbox.encodedPath, messageId.uid],
          );

          if (maps.isEmpty) {
            logger.d(
              '${_mailAccount.name}: message data not found for '
                  'guid ${messageId.guid} belonging to '
                  '${isUid ? 'uid' : 'sequence-id'} $id ',
            );
            continue;
          }

          // Convert the map to a MimeMessage
          final message = _mapToMimeMessage(maps.first);
          if (message != null) {
            // Add to cache for faster retrieval
            _messageCache.put(message.uid!, message);
            envelopes.add(message);
          }
        }

        // Yield to UI thread to prevent blocking
        await Future.delayed(Duration.zero);
      }

      // Update last refresh time
      _lastRefreshed = DateTime.now();

      if (envelopes.isNotEmpty) {
        // Sort by date
        envelopes.sort((a, b) {
          final dateA = a.decodeDate() ?? DateTime.now();
          final dateB = b.decodeDate() ?? DateTime.now();
          return dateB.compareTo(dateA);
        });

        // Update the messages list
        _messages.assignAll(envelopes);

        // Update the message subject
        _notifyListeners();
      }

      logger.d('${_mailAccount.name}: all messages loaded offline :-)');
      return envelopes;
    } catch (e) {
      logger.e('Error loading message envelopes: $e');
      return null;
    } finally {
      _releaseTransactionLock();
      _isLoading.value = false;
    }
  }

  /// Convert a database map to a MimeMessage with optimized parsing
  MimeMessage? _mapToMimeMessage(Map<String, dynamic> map) {
    try {
      final mimeSource = map['mime_source'] as String?;
      if (mimeSource != null && mimeSource.isNotEmpty) {
        // If we have the full MIME source, parse it
        // Use compute for heavy parsing to prevent UI blocking
        final message = MimeMessage.parseFromText(mimeSource);

        // Set the UID and sequence ID
        message.uid = map['uid'] as int;
        message.sequenceId = map['sequence_id'] as int;

        // Generate and set the GUID for compatibility
        final guid = _generateGuid(message.uid!);
        message.guid = guid;

        return message;
      } else {
        // Create a message from the envelope data
        final message = MimeMessage();

        // Set basic properties
        message.uid = map['uid'] as int;
        message.sequenceId = map['sequence_id'] as int;
        message.guid = _generateGuid(message.uid!);

        // Set flags
        message.isSeen = map['is_seen'] == 1;
        message.isFlagged = map['is_flagged'] == 1;
        message.isAnswered = map['is_answered'] == 1;
        message.isForwarded = map['is_forwarded'] == 1;

        // Set flags list
        message.flags = [];
        if (message.isSeen) message.flags!.add(r'\Seen');
        if (message.isFlagged) message.flags!.add(r'\Flagged');
        if (message.isAnswered) message.flags!.add(r'\Answered');
        if (map['is_draft'] == 1) message.flags!.add(r'\Draft');
        if (map['is_recent'] == 1) message.flags!.add(r'\Recent');

        // Set subject
        final subject = map['subject'] as String?;
        if (subject != null) {
          message.addHeader(MailConventions.headerSubject, subject);
        }

        // Set date
        final dateStr = map['date'] as String?;
        if (dateStr != null) {
          try {
            final date = DateTime.parse(dateStr);
            message.addHeader(MailConventions.headerDate, date.toIso8601String());
          } catch (e) {
            logger.e('Error parsing date: $e');
          }
        }

        // Set from
        final fromEmail = map['from_email'] as String?;
        final fromName = map['from_name'] as String?;
        if (fromEmail != null && fromEmail.isNotEmpty) {
          message.from = [MailAddress(fromName, fromEmail)];
        }

        // Set to
        final toEmail = map['to_email'] as String?;
        final toName = map['to_name'] as String?;
        if (toEmail != null && toEmail.isNotEmpty) {
          if (toName != null && toName.isNotEmpty) {
            // Try to match names with emails
            final emails = toEmail.split(', ');
            final names = toName.split(', ');

            if (emails.length == names.length) {
              message.to = List.generate(
                emails.length,
                    (i) => MailAddress(names[i], emails[i]),
              );
            } else {
              message.to = emails
                  .map((email) => MailAddress(null, email.trim()))
                  .toList();
            }
          } else {
            message.to = toEmail.split(', ')
                .map((email) => MailAddress(null, email.trim()))
                .toList();
          }
        }

        // Set cc
        final ccEmail = map['cc_email'] as String?;
        final ccName = map['cc_name'] as String?;
        if (ccEmail != null && ccEmail.isNotEmpty) {
          if (ccName != null && ccName.isNotEmpty) {
            // Try to match names with emails
            final emails = ccEmail.split(', ');
            final names = ccName.split(', ');

            if (emails.length == names.length) {
              message.cc = List.generate(
                emails.length,
                    (i) => MailAddress(names[i], emails[i]),
              );
            } else {
              message.cc = emails
                  .map((email) => MailAddress(null, email.trim()))
                  .toList();
            }
          } else {
            message.cc = ccEmail.split(', ')
                .map((email) => MailAddress(null, email.trim()))
                .toList();
          }
        }

        // Set bcc
        final bccEmail = map['bcc_email'] as String?;
        final bccName = map['bcc_name'] as String?;
        if (bccEmail != null && bccEmail.isNotEmpty) {
          if (bccName != null && bccName.isNotEmpty) {
            // Try to match names with emails
            final emails = bccEmail.split(', ');
            final names = bccName.split(', ');

            if (emails.length == names.length) {
              message.bcc = List.generate(
                emails.length,
                    (i) => MailAddress(names[i], emails[i]),
              );
            } else {
              message.bcc = emails
                  .map((email) => MailAddress(null, email.trim()))
                  .toList();
            }
          } else {
            message.bcc = bccEmail.split(', ')
                .map((email) => MailAddress(null, email.trim()))
                .toList();
          }
        }

        return message;
      }
    } catch (e) {
      logger.e('Error converting map to MimeMessage: $e');
      return null;
    }
  }

  /// Save message contents to storage with optimized writing
  Future<void> saveMessageContents(MimeMessage mimeMessage) async {
    final guid = mimeMessage.guid;
    final uid = mimeMessage.uid;

    if (guid != null && uid != null) {
      try {
        await _acquireTransactionLock();

        // Save the message to SQLite
        await _sqliteStorage.insertMessage(
          mimeMessage,
          _mailAccount.email,
          _mailbox.encodedPath,
        );

        // Update cache
        _messageCache.put(uid, mimeMessage);

        // Update the messages list if this message is already in it
        final index = _messages.indexWhere((m) => m.uid == uid);
        if (index >= 0) {
          _messages[index] = mimeMessage;
          _messages.refresh(); // Force UI update

          // Update the message subject
          _notifyListeners();
        }

        // Update last refresh time
        _lastRefreshed = DateTime.now();
      } catch (e) {
        logger.e('Error saving message contents: $e');
      } finally {
        _releaseTransactionLock();
      }
    }
  }

  /// Save message envelopes to storage with optimized batch processing
  Future<void> saveMessageEnvelopes(List<MimeMessage> messages) async {
    if (messages.isEmpty) return;

    var addedMessageIds = 0;
    final allMessageIds = _allMessageIds;

    try {
      await _acquireTransactionLock();

      // Use a transaction for better performance
      final db = await _sqliteStorage.database;
      await db.transaction((txn) async {
        for (final message in messages) {
          final uid = message.uid;
          if (uid == null) continue;

          // Check if message already exists
          final existingIndex = allMessageIds.indexWhere((id) => id.uid == uid);
          if (existingIndex >= 0) {
            // Update existing message
            await _sqliteStorage.insertMessage(
              message,
              _mailAccount.email,
              _mailbox.encodedPath,
              transaction: txn,
            );
          } else {
            // Add new message
            await _sqliteStorage.insertMessage(
              message,
              _mailAccount.email,
              _mailbox.encodedPath,
              transaction: txn,
            );

            // Add to _allMessageIds
            final guid = _generateGuid(uid);
            allMessageIds.add(StorageMessageId(
              sequenceId: message.sequenceId ?? 0,
              uid: uid,
              guid: guid,
            ));

            addedMessageIds++;

            // Update last fetched UID
            if (uid > _lastFetchedUid) {
              _lastFetchedUid = uid;
            }
          }

          // Update cache
          _messageCache.put(uid, message);
        }
      });

      // Update last refresh time
      _lastRefreshed = DateTime.now();

      // Update the messages list
      if (addedMessageIds > 0) {
        // Merge with existing messages
        final updatedMessages = List<MimeMessage>.from(_messages);

        // Add new messages that aren't already in the list
        for (final message in messages) {
          final uid = message.uid;
          if (uid == null) continue;

          if (!updatedMessages.any((m) => m.uid == uid)) {
            updatedMessages.add(message);
          } else {
            // Update existing message
            final index = updatedMessages.indexWhere((m) => m.uid == uid);
            if (index >= 0) {
              updatedMessages[index] = message;
            }
          }
        }

        // Sort by date
        updatedMessages.sort((a, b) {
          final dateA = a.decodeDate() ?? DateTime.now();
          final dateB = b.decodeDate() ?? DateTime.now();
          return dateB.compareTo(dateA);
        });

        _messages.assignAll(updatedMessages);

        // Update the message subject
        _notifyListeners();
      }

      logger.d('Saved ${messages.length} message envelopes, added $addedMessageIds new messages');
    } catch (e) {
      logger.e('Error saving message envelopes: $e');
    } finally {
      _releaseTransactionLock();
    }
  }

  /// Fetch message contents from storage with optimized loading
  Future<MimeMessage?> fetchMessageContents(
      MimeMessage message, {
        bool markAsSeen = false,
      }) async {
    final uid = message.uid;
    if (uid == null) return null;

    try {
      await _acquireTransactionLock();

      // Check cache first for better performance
      final cachedMessage = _messageCache.get(uid);
      if (cachedMessage != null && cachedMessage.mimeData != null) {
        // Mark as seen if requested
        if (markAsSeen && !cachedMessage.isSeen) {
          cachedMessage.isSeen = true;
          await updateMessageFlags(cachedMessage);
        }

        return cachedMessage;
      }

      // Query the message from SQLite
      final db = await _sqliteStorage.database;
      final List<Map<String, dynamic>> maps = await db.query(
        'messages',
        where: 'account_id = ? AND mailbox_path = ? AND uid = ?',
        whereArgs: [_mailAccount.email, _mailbox.encodedPath, uid],
      );

      if (maps.isEmpty) {
        logger.d('${_mailAccount.name}: message data not found for uid $uid');
        return null;
      }

      // Convert the map to a MimeMessage
      final fullMessage = _mapToMimeMessage(maps.first);
      if (fullMessage == null) {
        return null;
      }

      // Mark as seen if requested
      if (markAsSeen && !fullMessage.isSeen) {
        fullMessage.isSeen = true;
        await updateMessageFlags(fullMessage);
      }

      // Update cache
      _messageCache.put(uid, fullMessage);

      // Update last refresh time
      _lastRefreshed = DateTime.now();

      return fullMessage;
    } catch (e) {
      logger.e('Error fetching message contents: $e');
      return null;
    } finally {
      _releaseTransactionLock();
    }
  }

  /// Update message flags in storage with optimized writing
  Future<void> updateMessageFlags(MimeMessage message) async {
    final uid = message.uid;
    if (uid == null) return;

    try {
      await _acquireTransactionLock();

      // Update the message in SQLite
      await _sqliteStorage.updateMessageFlags(
        message,
        _mailAccount.email,
        _mailbox.encodedPath,
      );

      // Update cache
      _messageCache.put(uid, message);

      // Update the messages list if this message is already in it
      final index = _messages.indexWhere((m) => m.uid == uid);
      if (index >= 0) {
        _messages[index] = message;
        _messages.refresh(); // Force UI update

        // Update the message subject
        _notifyListeners();
      }

      // Update last refresh time
      _lastRefreshed = DateTime.now();
    } catch (e) {
      logger.e('Error updating message flags: $e');
    } finally {
      _releaseTransactionLock();
    }
  }

  /// Batch update message flags for better performance
  Future<void> batchUpdateMessageFlags(List<MimeMessage> messages) async {
    if (messages.isEmpty) return;

    try {
      await _acquireTransactionLock();

      // Use batch update for better performance
      await _sqliteStorage.batchUpdateMessageFlags(
        messages,
        _mailAccount.email,
        _mailbox.encodedPath,
      );

      // Update cache and messages list
      for (final message in messages) {
        final uid = message.uid;
        if (uid == null) continue;

        // Update cache
        _messageCache.put(uid, message);

        // Update the messages list if this message is already in it
        final index = _messages.indexWhere((m) => m.uid == uid);
        if (index >= 0) {
          _messages[index] = message;
        }
      }

      // Force UI update
      _messages.refresh();

      // Update the message subject
      _notifyListeners();

      // Update last refresh time
      _lastRefreshed = DateTime.now();
    } catch (e) {
      logger.e('Error batch updating message flags: $e');
    } finally {
      _releaseTransactionLock();
    }
  }

  /// Delete a message from storage with optimized writing
  Future<void> deleteMessage(MimeMessage message) async {
    final uid = message.uid;
    if (uid == null) return;

    try {
      await _acquireTransactionLock();

      // Delete the message from SQLite
      await _sqliteStorage.deleteMessage(
        message,
        _mailAccount.email,
        _mailbox.encodedPath,
      );

      // Remove from cache
      _messageCache.remove(uid);

      // Remove from _allMessageIds
      _allMessageIds.removeWhere((id) => id.uid == uid);

      // Remove from the messages list
      final index = _messages.indexWhere((m) => m.uid == uid);
      if (index >= 0) {
        _messages.removeAt(index);
        _messages.refresh(); // Force UI update

        // Update the message subject
        _notifyListeners();
      }

      // Update last refresh time
      _lastRefreshed = DateTime.now();
    } catch (e) {
      logger.e('Error deleting message: $e');
    } finally {
      _releaseTransactionLock();
    }
  }

  /// Delete all messages for this account
  Future<void> onAccountRemoved() async {
    try {
      await _acquireTransactionLock();

      // Delete all messages for this account from SQLite
      await _sqliteStorage.clearMailbox(
        _mailAccount.email,
        _mailbox.encodedPath,
      );

      // Clear cache
      _messageCache.clear();

      // Clear _allMessageIds
      _allMessageIds.clear();

      // Clear the messages list
      _messages.clear();
      _messages.refresh(); // Force UI update

      // Update the message subject
      _notifyListeners();

      // Update last refresh time
      _lastRefreshed = DateTime.now();
    } catch (e) {
      logger.e('Error removing account: $e');
    } finally {
      _releaseTransactionLock();
    }
  }

  /// Get the last fetched UID for incremental updates
  int getLastFetchedUid() {
    return _lastFetchedUid;
  }

  /// Force refresh the cache
  Future<void> refreshCache() async {
    try {
      await _acquireTransactionLock();

      // Clear cache
      _messageCache.clear();

      // Reload message IDs
      await _loadMessageIdsAsync();

      // Update last refresh time
      _lastRefreshed = DateTime.now();

      logger.d('Cache refreshed for mailbox: ${_mailbox.name}');
    } catch (e) {
      logger.e('Error refreshing cache: $e');
    } finally {
      _releaseTransactionLock();
    }
  }

  /// Notify listeners with debouncing to prevent UI jank
  void _notifyListeners() {
    // Cancel existing timer
    _debounceTimer?.cancel();

    // Set new timer
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (!_messageSubject.isClosed) {
        _messageSubject.add(_messages);
      }
    });
  }

  /// Handle message updates from SQLite storage
  void _handleMessageUpdate(List<MimeMessage> messages) {
    if (messages.isEmpty) return;

    // Update cache and messages list
    for (final message in messages) {
      final uid = message.uid;
      if (uid == null) continue;

      // Update cache
      _messageCache.put(uid, message);

      // Update the messages list if this message is already in it
      final index = _messages.indexWhere((m) => m.uid == uid);
      if (index >= 0) {
        _messages[index] = message;
      } else {
        // Add new message
        _messages.add(message);
      }
    }

    // Sort by date
    _messages.sort((a, b) {
      final dateA = a.decodeDate() ?? DateTime.now();
      final dateB = b.decodeDate() ?? DateTime.now();
      return dateB.compareTo(dateA);
    });

    // Force UI update
    _messages.refresh();

    // Update the message subject
    _notifyListeners();

    // Update last refresh time
    _lastRefreshed = DateTime.now();
  }

  /// Handle message deletions from SQLite storage
  void _handleMessageDelete(List<MimeMessage> messages) {
    if (messages.isEmpty) return;

    // Remove from cache and messages list
    for (final message in messages) {
      final uid = message.uid;
      if (uid == null) continue;

      // Remove from cache
      _messageCache.remove(uid);

      // Remove from _allMessageIds
      _allMessageIds.removeWhere((id) => id.uid == uid);

      // Remove from the messages list
      final index = _messages.indexWhere((m) => m.uid == uid);
      if (index >= 0) {
        _messages.removeAt(index);
      }
    }

    // Force UI update
    _messages.refresh();

    // Update the message subject
    _notifyListeners();

    // Update last refresh time
    _lastRefreshed = DateTime.now();
  }

  /// Handle message flag updates from SQLite storage
  void _handleMessageFlagUpdate(List<MimeMessage> messages) {
    if (messages.isEmpty) return;

    // Update cache and messages list
    for (final message in messages) {
      final uid = message.uid;
      if (uid == null) continue;

      // Update cache
      _messageCache.put(uid, message);

      // Update the messages list if this message is already in it
      final index = _messages.indexWhere((m) => m.uid == uid);
      if (index >= 0) {
        _messages[index] = message;
      }
    }

    // Force UI update
    _messages.refresh();

    // Update the message subject
    _notifyListeners();

    // Update last refresh time
    _lastRefreshed = DateTime.now();
  }

  /// Handle mailbox clear from SQLite storage
  void _handleMailboxClear() {
    // Clear cache
    _messageCache.clear();

    // Clear _allMessageIds
    _allMessageIds.clear();

    // Clear the messages list
    _messages.clear();
    _messages.refresh(); // Force UI update

    // Update the message subject
    _notifyListeners();

    // Update last refresh time
    _lastRefreshed = DateTime.now();
  }

  /// Dispose resources
  void dispose() {
    _debounceTimer?.cancel();
    _messageSubject.close();
  }
}

/// A listenable for message changes for compatibility
class _MessageListenable extends ValueListenable<List<MimeMessage>> {
  _MessageListenable(this._messages);

  final RxList<MimeMessage> _messages;
  final List<VoidCallback> _listeners = [];

  @override
  List<MimeMessage> get value => _messages;

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
    _messages.listen((_) {
      for (final callback in _listeners) {
        callback();
      }
    });
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }
}

/// A class to store message IDs
class StorageMessageId {
  StorageMessageId({
    required this.sequenceId,
    required this.uid,
    required this.guid,
  });

  final int sequenceId;
  final int uid;
  final int guid;
}

/// Enhanced LRU cache implementation
class _LRUCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap<K, V>();

  _LRUCache(this.maxSize);

  V? get(K key) {
    final value = _cache[key];
    if (value != null) {
      // Move to end (most recently used)
      _cache.remove(key);
      _cache[key] = value;
    }
    return value;
  }

  void put(K key, V value) {
    // Evict oldest if at capacity
    if (_cache.length >= maxSize && !_cache.containsKey(key)) {
      _cache.remove(_cache.keys.first);
    }

    // Add or update value
    _cache[key] = value;
  }

  void remove(K key) {
    _cache.remove(key);
  }

  void clear() {
    _cache.clear();
  }
}

// Message update types for compatibility with SqliteMimeStorage
enum MessageUpdateType {
  update,
  delete,
  flagUpdate,
  clear,
}
