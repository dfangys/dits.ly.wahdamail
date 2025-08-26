import 'dart:async';
import 'dart:convert';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/material.dart';

import 'sqlite_database_helper.dart';

/// SQLite implementation for email storage
/// 
/// Replaces the HiveMailboxMimeStorage class with SQLite-based storage
class SQLiteMailboxMimeStorage {
  final MailAccount mailAccount;
  final Mailbox mailbox;
  bool _isContinuousRange(List<int> list) {
    if (list.length < 2) return false;
    final sorted = List<int>.from(list)..sort();
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] != sorted[i - 1] + 1) {
        return false;
      }
    }
    return true;
  }
  // Stream controller for notifying listeners of changes
  final _dataStreamController = StreamController<List<MimeMessage>>.broadcast();
  Stream<List<MimeMessage>> get dataStream => _dataStreamController.stream;

  // Value notifier for UI updates
  final ValueNotifier<List<MimeMessage>> dataNotifier = ValueNotifier<List<MimeMessage>>([]);

  SQLiteMailboxMimeStorage({
    required this.mailAccount,
    required this.mailbox,
  });

  /// Initialize the storage
  Future<void> init() async {
    // Ensure mailbox is registered in database
    await _ensureMailboxExists();

    // Load initial data
    final messages = await loadAllMessages();
    dataNotifier.value = messages;
    _dataStreamController.add(messages);
  }

  /// Ensure the mailbox exists in the database
  Future<int> _ensureMailboxExists() async {
    final db = await SQLiteDatabaseHelper.instance.database;

    // CRITICAL FIX: Wrap all database operations in a single transaction to prevent locking
    return await db.transaction((txn) async {
      try {
        // Check if mailbox exists
        final List<Map<String, dynamic>> result = await txn.query(
          SQLiteDatabaseHelper.tableMailboxes,
          where: '${SQLiteDatabaseHelper.columnAccountEmail} = ? AND ${SQLiteDatabaseHelper.columnPath} = ?',
          whereArgs: [mailAccount.email, mailbox.path],
        );

        if (result.isNotEmpty) {
          // Update mailbox data within transaction
          await txn.update(
            SQLiteDatabaseHelper.tableMailboxes,
            _mailboxToMap(),
            where: '${SQLiteDatabaseHelper.columnAccountEmail} = ? AND ${SQLiteDatabaseHelper.columnPath} = ?',
            whereArgs: [mailAccount.email, mailbox.path],
          );
          return result.first[SQLiteDatabaseHelper.columnId] as int;
        } else {
          // Insert new mailbox within transaction
          return await txn.insert(
            SQLiteDatabaseHelper.tableMailboxes,
            _mailboxToMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error ensuring mailbox exists: $e');
        }
        rethrow;
      }
    });
  }

  /// Convert mailbox to map for database storage
  Map<String, dynamic> _mailboxToMap() {
    return {
      SQLiteDatabaseHelper.columnAccountEmail: mailAccount.email,
      SQLiteDatabaseHelper.columnName: mailbox.name,
      SQLiteDatabaseHelper.columnPath: mailbox.path,
      SQLiteDatabaseHelper.columnFlags: mailbox.flags.join(','),
      SQLiteDatabaseHelper.columnPathSeparator: mailbox.pathSeparator,
      SQLiteDatabaseHelper.columnHasChildren: SQLiteDatabaseHelper.boolToInt(mailbox.hasChildren),
      SQLiteDatabaseHelper.columnMessagesExists: mailbox.messagesExists,
      SQLiteDatabaseHelper.columnMessagesRecent: mailbox.messagesRecent,
      SQLiteDatabaseHelper.columnMessagesUnseen: mailbox.messagesUnseen,
      SQLiteDatabaseHelper.columnUidNext: mailbox.uidNext,
      SQLiteDatabaseHelper.columnUidValidity: mailbox.uidValidity,
    };
  }

  /// Get mailbox ID from database with transaction safety
  Future<int> _getMailboxId() async {
    final db = await SQLiteDatabaseHelper.instance.database;

    // CRITICAL FIX: Use read transaction for consistency and to prevent locking issues
    return await db.transaction((txn) async {
      final List<Map<String, dynamic>> result = await txn.query(
        SQLiteDatabaseHelper.tableMailboxes,
        columns: [SQLiteDatabaseHelper.columnId],
        where: '${SQLiteDatabaseHelper.columnAccountEmail} = ? AND ${SQLiteDatabaseHelper.columnPath} = ?',
        whereArgs: [mailAccount.email, mailbox.path],
      );

      if (result.isEmpty) {
        throw Exception('Mailbox not found in database: ${mailbox.path}');
      }

      return result.first[SQLiteDatabaseHelper.columnId] as int;
    });
  }

  /// Save message envelopes to database with optimized transaction handling
  Future<void> saveMessageEnvelopes(List<MimeMessage> messages) async {
    if (messages.isEmpty) return;

    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      
      // Get mailbox ID outside of the main transaction to reduce lock time
      int? cachedMailboxId;
      try {
        cachedMailboxId = await _getMailboxId();
      } catch (e) {
        if (kDebugMode) {
          print('📧 Error getting mailbox ID: $e');
        }
        return; // Exit early if we can't get mailbox ID
      }

      // Use a single optimized transaction for all messages
      await db.transaction((txn) async {
        final batch = txn.batch();
        
        for (final message in messages) {
          try {
            final Map<String, dynamic> messageMap = {
              SQLiteDatabaseHelper.columnMailboxId: cachedMailboxId,
              SQLiteDatabaseHelper.columnUid: message.uid,
              SQLiteDatabaseHelper.columnSequenceId: message.sequenceId,
              SQLiteDatabaseHelper.columnFlags: message.flags?.map((f) => f.name).join(',') ?? '',
              SQLiteDatabaseHelper.columnEnvelope: jsonEncode(_envelopeToMap(message.envelope)),
              SQLiteDatabaseHelper.columnSize: message.size?.totalBytes ?? 0,
              SQLiteDatabaseHelper.columnDate: message.decodeDate()?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
              SQLiteDatabaseHelper.columnSubject: message.decodeSubject() ?? '',
              SQLiteDatabaseHelper.columnSender: message.from?.isNotEmpty == true ? message.from!.first.email : '',
              SQLiteDatabaseHelper.columnRecipients: message.to?.map((addr) => addr.email).join(',') ?? '',
              SQLiteDatabaseHelper.columnIsSeen: message.isSeen,
              SQLiteDatabaseHelper.columnIsFlagged: message.isFlagged,
              SQLiteDatabaseHelper.columnIsDeleted: message.isDeleted,
              SQLiteDatabaseHelper.columnIsAnswered: message.isAnswered,
              SQLiteDatabaseHelper.columnIsDraft: message.isDraft,
            };

            // Use INSERT OR REPLACE for better performance
            batch.insert(
              SQLiteDatabaseHelper.tableEmails,
              messageMap,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } catch (e) {
            if (kDebugMode) {
              print('📧 Error preparing message for batch: $e');
            }
            // Continue with other messages even if one fails
          }
        }
        
        // Execute all operations in a single batch
        await batch.commit(noResult: true);
        
        if (kDebugMode) {
          print('📧 Successfully saved ${messages.length} messages to database');
        }
      });

      // Notify listeners after successful save
      _notifyDataChanged();
      
    } catch (e) {
      if (kDebugMode) {
        print('📧 Database transaction error in saveMessageEnvelopes: $e');
      }
      // Don't rethrow - just log the error to prevent crashes
    }

  /// Helper method to convert envelope to map
  Map<String, dynamic> _envelopeToMap(Envelope? envelope) {
    if (envelope == null) return {};
    
    return {
      'date': envelope.date?.millisecondsSinceEpoch,
      'subject': envelope.subject,
      'from': envelope.from?.map((addr) => addr.toString()).toList(),
      'to': envelope.to?.map((addr) => addr.toString()).toList(),
      'cc': envelope.cc?.map((addr) => addr.toString()).toList(),
      'bcc': envelope.bcc?.map((addr) => addr.toString()).toList(),
      'messageId': envelope.messageId,
      'inReplyTo': envelope.inReplyTo,
    };
  }

  /// Notify listeners of data changes
  void _notifyDataChanged() async {
    try {
      final updatedMessages = await loadAllMessages();
      dataNotifier.value = updatedMessages;
      _dataStreamController.add(updatedMessages);
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error notifying data changes: $e');
      }
    }
  }

  /// Delete message envelopes from database
  Future<void> deleteMessageEnvelopes(MessageSequence sequence) async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      final mailboxId = await _getMailboxId();

      List<Map<String, dynamic>> results;

      if (sequence.isUidSequence) {
        // Handle UID sequence
        final sequenceList = sequence.toList();
        final isRange = sequenceList.length >= 2 && _isContinuousRange(sequenceList);

        if (isRange) {
          int start = sequence.toList().first;
          int? end = sequence.toList().last;

          results = await db.query(
            SQLiteDatabaseHelper.tableEmails,
            where: '${SQLiteDatabaseHelper.columnMailboxId} = ? AND ${SQLiteDatabaseHelper.columnUid} >= ? AND ${SQLiteDatabaseHelper.columnUid} <= ?',
            whereArgs: [mailboxId, start, end ?? 999999999],
            orderBy: '${SQLiteDatabaseHelper.columnDate} DESC',
          );
        } else {
          // Handle individual UIDs
          final List<int> uids = sequence.toList();
          if (uids.isEmpty) return [];

          final placeholders = uids.map((_) => '?').join(',');
          results = await db.query(
            SQLiteDatabaseHelper.tableEmails,
            where: '${SQLiteDatabaseHelper.columnMailboxId} = ? AND ${SQLiteDatabaseHelper.columnUid} IN ($placeholders)',
            whereArgs: [mailboxId, ...uids],
            orderBy: '${SQLiteDatabaseHelper.columnDate} DESC',
          );
        }
      } else {
        // Handle sequence numbers (page-based)
        final sequenceList = sequence.toList();
        final isRange = sequenceList.length >= 2 && _isContinuousRange(sequenceList);

        if (isRange) {          int start = sequence.toList().first;
          int? end = sequence.toList().last;

          results = await db.query(
            SQLiteDatabaseHelper.tableEmails,
            where: '${SQLiteDatabaseHelper.columnMailboxId} = ?',
            whereArgs: [mailboxId],
            orderBy: '${SQLiteDatabaseHelper.columnDate} DESC',
            limit: end != null ? end - start + 1 : null,
            offset: start - 1,
          );
        } else {
          // Handle individual sequence numbers
          final List<int> seqNums = sequence.toList();
          if (seqNums.isEmpty) return [];

          // For sequence numbers, we need to get all messages and filter
          final allMessages = await db.query(
            SQLiteDatabaseHelper.tableEmails,
            where: '${SQLiteDatabaseHelper.columnMailboxId} = ?',
            whereArgs: [mailboxId],
            orderBy: '${SQLiteDatabaseHelper.columnDate} DESC',
          );

          // Filter by sequence numbers
          final List<Map<String, dynamic>> filteredResults = [];
          for (int i = 0; i < allMessages.length; i++) {
            if (seqNums.contains(i + 1)) {
              filteredResults.add(allMessages[i]);
            }
          }
          results = filteredResults;
        }
      }

      // Convert database results to MimeMessage objects
      return await compute(_mapsToMessages, results);
    } catch (e) {
      if (kDebugMode) {
        print('Error loading message envelopes: $e');
      }
      return [];
    }
  }

  /// Load all messages from database
  Future<List<MimeMessage>> loadAllMessages() async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      
      // CRITICAL FIX: Use transaction for consistent read operations
      final results = await db.transaction((txn) async {
        final mailboxId = await _getMailboxIdFromTransaction(txn);

        return await txn.query(
          SQLiteDatabaseHelper.tableEmails,
          where: '${SQLiteDatabaseHelper.columnMailboxId} = ?',
          whereArgs: [mailboxId],
          orderBy: '${SQLiteDatabaseHelper.columnDate} DESC',
        );
      });

      return results.map((row) => _mapToMessage(row)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error loading messages: $e');
      }
      return [];
    }
  }

  /// Load message envelopes (alias for loadAllMessages for compatibility)
  Future<List<MimeMessage>> loadMessageEnvelopes(MessageSequence sequence) async {
    // For now, return all messages - could be optimized to filter by sequence
    return await loadAllMessages();
  }

  /// Get mailbox ID within an existing transaction
  Future<int> _getMailboxIdFromTransaction(Transaction txn) async {
    final List<Map<String, dynamic>> result = await txn.query(
      SQLiteDatabaseHelper.tableMailboxes,
      columns: [SQLiteDatabaseHelper.columnId],
      where: '${SQLiteDatabaseHelper.columnName} = ? AND ${SQLiteDatabaseHelper.columnAccountEmail} = ?',
      whereArgs: [mailbox.name, mailAccount.email],
    );

    if (result.isEmpty) {
      throw Exception('Mailbox not found in database');
    }

    return result.first[SQLiteDatabaseHelper.columnId] as int;
  }

  /// Add onAccountRemoved method for compatibility
  Future<void> onAccountRemoved() async {
    try {
      await deleteAllMessages();
      if (kDebugMode) {
        print('📧 Account removed, all messages deleted');
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error removing account: $e');
      }
    }
  }

  /// Helper method to convert database row to MimeMessage
  MimeMessage _mapToMessage(Map<String, dynamic> row) {
    final message = MimeMessage();
    
    // Set basic properties
    message.uid = row[SQLiteDatabaseHelper.columnUid];
    message.sequenceId = row[SQLiteDatabaseHelper.columnSequenceId];
    message.isSeen = row[SQLiteDatabaseHelper.columnIsSeen] == 1;
    message.isFlagged = row[SQLiteDatabaseHelper.columnIsFlagged] == 1;
    message.isDeleted = row[SQLiteDatabaseHelper.columnIsDeleted] == 1;
    message.isAnswered = row[SQLiteDatabaseHelper.columnIsAnswered] == 1;
    message.isDraft = row[SQLiteDatabaseHelper.columnIsDraft] == 1;
    
    // Set envelope if available
    final envelopeJson = row[SQLiteDatabaseHelper.columnEnvelope];
    if (envelopeJson != null && envelopeJson.isNotEmpty) {
      try {
        final envelopeMap = jsonDecode(envelopeJson);
        message.envelope = _mapToEnvelope(envelopeMap);
      } catch (e) {
        if (kDebugMode) {
          print('📧 Error parsing envelope: $e');
        }
      }
    }
    
    return message;
  }

  /// Helper method to convert map to Envelope
  Envelope _mapToEnvelope(Map<String, dynamic> map) {
    final envelope = Envelope();
    
    if (map['date'] != null) {
      envelope.date = DateTime.fromMillisecondsSinceEpoch(map['date']);
    }
    
    envelope.subject = map['subject'];
    envelope.messageId = map['messageId'];
    envelope.inReplyTo = map['inReplyTo'];
    
    // Convert address lists
    if (map['from'] != null) {
      envelope.from = (map['from'] as List).map((addr) => MailAddress.parse(addr)).toList();
    }
    if (map['to'] != null) {
      envelope.to = (map['to'] as List).map((addr) => MailAddress.parse(addr)).toList();
    }
    if (map['cc'] != null) {
      envelope.cc = (map['cc'] as List).map((addr) => MailAddress.parse(addr)).toList();
    }
    if (map['bcc'] != null) {
      envelope.bcc = (map['bcc'] as List).map((addr) => MailAddress.parse(addr)).toList();
    }
    
    return envelope;
  }

  /// Dispose resources
  void dispose() {
    _dataStreamController.close();
  }
}
