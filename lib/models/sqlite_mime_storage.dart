import 'dart:async';
import 'dart:convert';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/perf/perf_tracer.dart';
import 'sqlite_database_helper.dart';

/// SQLite implementation for email storage
/// 
/// Replaces the HiveMailboxMimeStorage class with SQLite-based storage
class SQLiteMailboxMimeStorage {
  final MailAccount mailAccount;
  final Mailbox mailbox;
  
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
    try {
      // Ensure mailbox is registered in database
      await _ensureMailboxExists();

      // CRITICAL FIX: Check if we need to migrate address format
      bool migrationOccurred = await _migrateAddressFormatIfNeeded();

      // Load initial data
      final messages = await loadAllMessages();
      dataNotifier.value = messages;
      _dataStreamController.add(messages);

      // Schedule backfill for derived fields (v5) without blocking init
      // This will populate sender_name and normalized_subject for existing rows.
      // Day bucket is backfilled via SQL during migration.
      // Limit the amount processed per run to avoid UI jank.
      // Best-effort; failures are logged in debug mode.
      // ignore: unawaited_futures
      Future(() => backfillDerivedFields(maxRows: 800));
      
      // If migration occurred and we have no messages, we need to trigger a refresh
      if (migrationOccurred && messages.isEmpty) {
        if (kDebugMode) {
          print('📧 Migration completed but no messages found - refresh needed');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error initializing SQLite storage: $e');
      }
    }
  }

  /// Migrate address format if needed (clear old data with string-based addresses)
  /// Returns true if migration occurred (database was cleared)
  Future<bool> _migrateAddressFormatIfNeeded() async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      
      if (kDebugMode) {
        print('📧 Starting address format migration check for mailbox: ${mailbox.name}');
      }
      
      // Check if we have any messages with old address format
      final result = await db.query(
        SQLiteDatabaseHelper.tableEmails,
        columns: [SQLiteDatabaseHelper.columnEnvelope],
        limit: 1,
      );
      
      if (kDebugMode) {
        print('📧 Found ${result.length} messages in database for migration check');
      }
      
      if (result.isNotEmpty) {
        final envelopeJson = result.first[SQLiteDatabaseHelper.columnEnvelope];
        if (envelopeJson != null && envelopeJson is String && envelopeJson.isNotEmpty) {
          try {
final envelopeMap = jsonDecode(envelopeJson);
            
            if (kDebugMode) {
              print('📧 Checking envelope format: ${envelopeMap.toString()}');
            }
            
            // Check if addresses are in old string format
            if (envelopeMap['from'] != null && envelopeMap['from'] is List) {
              final fromList = envelopeMap['from'] as List;
              if (fromList.isNotEmpty && fromList.first is String) {
                // Old format detected - clear all messages to force re-fetch
                if (kDebugMode) {
                  print('📧 Old address format detected - clearing database for migration');
                }
                
                final mailboxId = await _getMailboxId();
                await db.delete(
                  SQLiteDatabaseHelper.tableEmails,
                  where: '${SQLiteDatabaseHelper.columnMailboxId} = ?',
                  whereArgs: [mailboxId],
                );
                
                if (kDebugMode) {
                  print('📧 Database cleared - messages will be re-fetched with new address format');
                }
                return true; // Migration occurred
              } else {
                if (kDebugMode) {
                  print('📧 New address format detected - no migration needed');
                }
                return false; // No migration needed
              }
            } else {
              if (kDebugMode) {
                print('📧 No from addresses found in envelope - clearing database to be safe');
              }
              // Clear database if envelope structure is unexpected
              final mailboxId = await _getMailboxId();
              await db.delete(
                SQLiteDatabaseHelper.tableEmails,
                where: '${SQLiteDatabaseHelper.columnMailboxId} = ?',
                whereArgs: [mailboxId],
              );
              return true; // Migration occurred
            }
          } catch (e) {
            // If we can't parse the envelope, it's probably corrupted - clear it
            if (kDebugMode) {
              print('📧 Corrupted envelope data detected - clearing database');
            }
            final mailboxId = await _getMailboxId();
            await db.delete(
              SQLiteDatabaseHelper.tableEmails,
              where: '${SQLiteDatabaseHelper.columnMailboxId} = ?',
              whereArgs: [mailboxId],
            );
            return true; // Migration occurred
          }
        } else {
          if (kDebugMode) {
            print('📧 Empty or null envelope data - clearing database');
          }
          // Clear database if envelope is empty or null
          final mailboxId = await _getMailboxId();
          await db.delete(
            SQLiteDatabaseHelper.tableEmails,
            where: '${SQLiteDatabaseHelper.columnMailboxId} = ?',
            whereArgs: [mailboxId],
          );
          return true; // Migration occurred
        }
      } else {
        if (kDebugMode) {
          print('📧 No messages found in database - no migration needed');
        }
        return false; // No migration needed
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error during address format migration: $e');
      }
      return false; // No migration occurred due to error
    }
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
          columns: [SQLiteDatabaseHelper.columnId],
          where: '${SQLiteDatabaseHelper.columnName} = ? AND ${SQLiteDatabaseHelper.columnAccountEmail} = ?',
          whereArgs: [mailbox.name, mailAccount.email],
        );

        if (result.isNotEmpty) {
          return result.first[SQLiteDatabaseHelper.columnId] as int;
        }

        // Create mailbox if it doesn't exist
        final mailboxId = await txn.insert(
          SQLiteDatabaseHelper.tableMailboxes,
          {
            SQLiteDatabaseHelper.columnName: mailbox.name,
            SQLiteDatabaseHelper.columnAccountEmail: mailAccount.email,
            SQLiteDatabaseHelper.columnPath: mailbox.encodedPath,
            SQLiteDatabaseHelper.columnFlags: mailbox.flags.map((f) => f.name).join(','),
SQLiteDatabaseHelper.columnUidNext: mailbox.uidNext,
              SQLiteDatabaseHelper.columnUidValidity: mailbox.uidValidity,
              SQLiteDatabaseHelper.columnMessagesExists: mailbox.messagesExists,
              SQLiteDatabaseHelper.columnMessagesUnseen: mailbox.messagesUnseen,
              SQLiteDatabaseHelper.columnMessagesRecent: mailbox.messagesRecent,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        if (kDebugMode) {
          print('📧 Created mailbox in database: ${mailbox.name} with ID: $mailboxId');
        }

        return mailboxId;
      } catch (e) {
        if (kDebugMode) {
          print('📧 Error ensuring mailbox exists: $e');
        }
        rethrow;
      }
    });
  }

  /// Get mailbox ID from database with transaction safety
  Future<int> _getMailboxId() async {
    final db = await SQLiteDatabaseHelper.instance.database;

    // CRITICAL FIX: Use read transaction for consistency and to prevent locking issues
    return await db.transaction((txn) async {
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
    });
  }

  /// Save message envelopes to database with optimized transaction handling
  Future<void> saveMessageEnvelopes(List<MimeMessage> messages) async {
    if (messages.isEmpty) return;

    final endTrace = PerfTracer.begin('storage.saveMessageEnvelopes', args: {'count': messages.length});
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
            // Derive lightweight preview and attachment flag (best-effort)
            final String previewText = _derivePreviewText(message);
            final bool hasAttachments = _deriveHasAttachments(message);

            final int dateMillis = message.decodeDate()?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
            final String senderName = _deriveSenderName(message);
            final String normalizedSubject = _normalizeSubject(message.decodeSubject() ?? '');
            final int dayBucket = dateMillis ~/ 86400000; // UTC day bucket

            final Map<String, dynamic> messageMap = {
              SQLiteDatabaseHelper.columnMailboxId: cachedMailboxId,
              SQLiteDatabaseHelper.columnUid: message.uid,
              SQLiteDatabaseHelper.columnSequenceId: message.sequenceId,
              SQLiteDatabaseHelper.columnEmailFlags: message.flags?.map((f) => f.toString()).join(',') ?? '',
              SQLiteDatabaseHelper.columnEnvelope: jsonEncode(_envelopeToMap(message.envelope)),
              SQLiteDatabaseHelper.columnSize: message.size ?? 0,
              SQLiteDatabaseHelper.columnDate: dateMillis,
              SQLiteDatabaseHelper.columnSubject: message.decodeSubject() ?? '',
              SQLiteDatabaseHelper.columnFrom: message.from?.isNotEmpty == true ? message.from!.first.email : '',
              SQLiteDatabaseHelper.columnTo: message.to?.map((addr) => addr.email).join(',') ?? '',
              SQLiteDatabaseHelper.columnIsSeen: message.isSeen ? 1 : 0,
              SQLiteDatabaseHelper.columnIsFlagged: message.isFlagged ? 1 : 0,
              SQLiteDatabaseHelper.columnIsDeleted: message.isDeleted ? 1 : 0,
              SQLiteDatabaseHelper.columnIsAnswered: message.isAnswered ? 1 : 0,
              SQLiteDatabaseHelper.columnPreviewText: previewText,
              SQLiteDatabaseHelper.columnHasAttachments: hasAttachments ? 1 : 0,
              SQLiteDatabaseHelper.columnSenderName: senderName,
              SQLiteDatabaseHelper.columnNormalizedSubject: normalizedSubject,
              SQLiteDatabaseHelper.columnDayBucket: dayBucket,
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
    } finally {
      try { endTrace(); } catch (_) {}
    }
  }

  /// Helper method to convert envelope to map
  Map<String, dynamic> _envelopeToMap(Envelope? envelope) {
    if (envelope == null) return {};
    
    return {
      'date': envelope.date?.millisecondsSinceEpoch,
      'subject': envelope.subject,
      'from': envelope.from?.map((addr) => {
        'email': addr.email,
        'personalName': addr.personalName,
      }).toList(),
      'to': envelope.to?.map((addr) => {
        'email': addr.email,
        'personalName': addr.personalName,
      }).toList(),
      'cc': envelope.cc?.map((addr) => {
        'email': addr.email,
        'personalName': addr.personalName,
      }).toList(),
      'bcc': envelope.bcc?.map((addr) => {
        'email': addr.email,
        'personalName': addr.personalName,
      }).toList(),
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

  /// Public: reload from DB and notify listeners (when external writes occurred)
  Future<void> refreshFromDatabase() async {
    _notifyDataChanged();
  }

  /// Delete message envelopes from database
  Future<void> deleteMessageEnvelopes(MessageSequence sequence) async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      final mailboxId = await _getMailboxId();

      int requested = 0;
      await db.transaction((txn) async {
        if (sequence.isUidSequence) {
          // Delete by UID
          for (final uid in sequence.toList()) {
            requested++;
            await txn.delete(
              SQLiteDatabaseHelper.tableEmails,
              where: '${SQLiteDatabaseHelper.columnMailboxId} = ? AND ${SQLiteDatabaseHelper.columnUid} = ?',
              whereArgs: [mailboxId, uid],
            );
          }
        } else {
          // Delete by sequence ID
          for (final seqId in sequence.toList()) {
            requested++;
            await txn.delete(
              SQLiteDatabaseHelper.tableEmails,
              where: '${SQLiteDatabaseHelper.columnMailboxId} = ? AND ${SQLiteDatabaseHelper.columnSequenceId} = ?',
              whereArgs: [mailboxId, seqId],
            );
          }
        }
      });

      if (kDebugMode) {
        final mode = sequence.isUidSequence ? 'UID' : 'SEQ';
        print('📧 DB deleteMessageEnvelopes: requested=$requested mode=$mode mailbox=${mailbox.name}');
      }

      _notifyDataChanged();
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error deleting message envelopes: $e');
      }
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

  /// [DEPRECATED] Prefer using loadMessagePage/countMessages for pagination.
  /// This remains for compatibility when a specific MessageSequence is required.
  /// If the sequence represents a recent contiguous range, callers should switch
  /// to page-based APIs for better index utilization.
  Future<List<MimeMessage>> loadMessageEnvelopes(MessageSequence sequence) async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      final mailboxId = await _getMailboxId();

      // Convert sequence to a concrete list of IDs.
      // We then map to a bounded SQL range when possible.
      final ids = sequence.toList();
      if (ids.isEmpty) return [];

      // Determine whether we're dealing with UID-based sequence or sequence-id
final isUid = sequence.isUidSequence;

      // Prefer BETWEEN for contiguous ranges to keep the SQL simple and fast.
      // If the list is not contiguous, BETWEEN(min, max) may over-fetch a small superset,
      // which is acceptable and we will filter in memory afterward.
      final int minId = ids.reduce((a, b) => a < b ? a : b);
      final int maxId = ids.reduce((a, b) => a > b ? a : b);

      // Build where clause
      final whereColumn = isUid
          ? SQLiteDatabaseHelper.columnUid
          : SQLiteDatabaseHelper.columnSequenceId;

      // Query a bounded range first for performance
      final results = await db.query(
        SQLiteDatabaseHelper.tableEmails,
        where: '${SQLiteDatabaseHelper.columnMailboxId} = ? AND $whereColumn BETWEEN ? AND ?',
        whereArgs: [mailboxId, minId, maxId],
        orderBy: isUid
            ? '${SQLiteDatabaseHelper.columnUid} DESC'
            : '${SQLiteDatabaseHelper.columnSequenceId} DESC',
      );

      // If the range was non-contiguous, filter precisely to requested IDs
      final idSet = ids.toSet();
      final filtered = results.where((row) {
        final value = row[whereColumn];
        if (value == null) return false;
        if (value is int) return idSet.contains(value);
        final parsed = int.tryParse(value.toString());
        return parsed != null && idSet.contains(parsed);
      }).toList();

      // Map to messages and return
      return filtered.map((row) => _mapToMessage(row)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error loading message envelopes by sequence: $e');
      }
      // Fallback to full load as a last resort (still better to return something)
      return await loadAllMessages();
    }
  }

  /// Page-based loading by date (DESC) for mailbox virtualization
  Future<List<MimeMessage>> loadMessagePage({required int limit, required int offset}) async {
    final endTrace = PerfTracer.begin('storage.loadMessagePage', args: {'limit': limit, 'offset': offset});
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      final mailboxId = await _getMailboxId();

      final results = await db.query(
        SQLiteDatabaseHelper.tableEmails,
        where: '${SQLiteDatabaseHelper.columnMailboxId} = ?',
        whereArgs: [mailboxId],
        orderBy: '${SQLiteDatabaseHelper.columnDate} DESC',
        limit: limit,
        offset: offset,
      );

      return results.map((row) => _mapToMessage(row)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error loading message page: $e');
      }
      return [];
    } finally {
      try { endTrace(); } catch (_) {}
    }
  }

  /// Validate index usage via EXPLAIN QUERY PLAN for the page query (debug only)
  Future<List<Map<String, Object?>>> explainQueryPlanForPage({int limit = 50, int offset = 0}) async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      final mailboxId = await _getMailboxId();
      const sql = 'EXPLAIN QUERY PLAN SELECT ${SQLiteDatabaseHelper.columnId} FROM ${SQLiteDatabaseHelper.tableEmails} '
          'WHERE ${SQLiteDatabaseHelper.columnMailboxId} = ? '
          'ORDER BY ${SQLiteDatabaseHelper.columnDate} DESC LIMIT ? OFFSET ?';
      final res = await db.rawQuery(sql, [mailboxId, limit, offset]);
      if (kDebugMode) {
        print('📈 EXPLAIN QUERY PLAN: $res');
      }
      return res;
    } catch (e) {
      if (kDebugMode) {
        print('📈 Error explaining query plan: $e');
      }
      return const [];
    }
  }

  /// Count messages for this mailbox
  Future<int> countMessages() async {
    final endTrace = PerfTracer.begin('storage.countMessages');
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      final mailboxId = await _getMailboxId();
      final result = await db.rawQuery(
        'SELECT COUNT(*) AS cnt FROM ${SQLiteDatabaseHelper.tableEmails} WHERE ${SQLiteDatabaseHelper.columnMailboxId} = ?',
        [mailboxId],
      );
      final count = result.isNotEmpty ? (result.first['cnt'] as int? ?? 0) : 0;
      return count;
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error counting messages: $e');
      }
      return 0;
    } finally {
      try { endTrace(); } catch (_) {}
    }
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

  /// Fetch message contents (compatibility method)
  Future<MimeMessage?> fetchMessageContents(MimeMessage message) async {
    // This would typically fetch full message content from server
    // For now, return the message as-is
    return message;
  }

  /// Delete a single message
  Future<void> deleteMessage(MimeMessage message) async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      final mailboxId = await _getMailboxId();

      await db.transaction((txn) async {
        if (message.uid != null) {
          await txn.delete(
            SQLiteDatabaseHelper.tableEmails,
            where: '${SQLiteDatabaseHelper.columnMailboxId} = ? AND ${SQLiteDatabaseHelper.columnUid} = ?',
            whereArgs: [mailboxId, message.uid],
          );
        } else if (message.sequenceId != null) {
          await txn.delete(
            SQLiteDatabaseHelper.tableEmails,
            where: '${SQLiteDatabaseHelper.columnMailboxId} = ? AND ${SQLiteDatabaseHelper.columnSequenceId} = ?',
            whereArgs: [mailboxId, message.sequenceId],
          );
        }
      });

      _notifyDataChanged();
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error deleting message: $e');
      }
    }
  }

  /// Delete all messages in this mailbox
  Future<void> deleteAllMessages() async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      final mailboxId = await _getMailboxId();

      await db.transaction((txn) async {
        await txn.delete(
          SQLiteDatabaseHelper.tableEmails,
          where: '${SQLiteDatabaseHelper.columnMailboxId} = ?',
          whereArgs: [mailboxId],
        );
      });

      _notifyDataChanged();
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error deleting all messages: $e');
      }
    }
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
    message.isSeen = (row[SQLiteDatabaseHelper.columnIsSeen] ?? 0) == 1;
    message.isFlagged = (row[SQLiteDatabaseHelper.columnIsFlagged] ?? 0) == 1;
    message.isDeleted = (row[SQLiteDatabaseHelper.columnIsDeleted] ?? 0) == 1;
    message.isAnswered = (row[SQLiteDatabaseHelper.columnIsAnswered] ?? 0) == 1;
    
    // Set size
    final sizeValue = row[SQLiteDatabaseHelper.columnSize];
    if (sizeValue != null) {
      message.size = sizeValue is int ? sizeValue : int.tryParse(sizeValue.toString()) ?? 0;
    }
    
    // Persisted preview and attachment metadata to speed up UI
    final preview = row[SQLiteDatabaseHelper.columnPreviewText];
    if (preview != null && preview.toString().isNotEmpty) {
      try {
        message.setHeader('x-preview', preview.toString());
      } catch (_) {}
    }
    final hasAtt = row[SQLiteDatabaseHelper.columnHasAttachments];
    if (hasAtt != null) {
      try {
        message.setHeader('x-has-attachments', (hasAtt is int ? hasAtt : int.tryParse(hasAtt.toString()) ?? 0) == 1 ? '1' : '0');
      } catch (_) {}
    }
    // Mark message as "ready" when we have enough metadata for a stable tile
    // Relaxed gating: envelope with sender or subject OR any preview/attachment hint
    try {
      final previewKnown = preview != null && preview.toString().isNotEmpty;
      final hasAttKnown = hasAtt != null;
      final env = message.envelope;
      final hasFrom = env?.from?.isNotEmpty == true;
      final subj = (message.decodeSubject() ?? env?.subject ?? '').toString().trim();
      final hasSubject = subj.isNotEmpty;
      if ((hasFrom || hasSubject) || previewKnown || hasAttKnown) {
        message.setHeader('x-ready', '1');
      }
    } catch (_) {}
    
    // Set envelope if available
    final envelopeJson = row[SQLiteDatabaseHelper.columnEnvelope];
    if (envelopeJson != null && envelopeJson.isNotEmpty) {
      try {
        final envelopeMap = jsonDecode(envelopeJson);
        message.envelope = _mapToEnvelope(envelopeMap);
        
        // Fill missing subject/from from denormalized columns to avoid Unknown tiles
        try {
          final subjRow = row[SQLiteDatabaseHelper.columnSubject];
          if ((message.envelope?.subject == null || message.envelope!.subject!.isEmpty) && subjRow != null) {
            message.envelope!.subject = subjRow.toString();
          }
          final fromRow = row[SQLiteDatabaseHelper.columnFrom];
          if (message.envelope?.from == null || (message.envelope!.from?.isEmpty ?? true)) {
            if (fromRow != null && fromRow.toString().isNotEmpty) {
              final senderName = row[SQLiteDatabaseHelper.columnSenderName]?.toString();
              message.envelope!.from = [MailAddress(senderName ?? '', fromRow.toString())];
            }
          }
          // Hydrate envelope.to from denormalized column if missing
          final toRow = row[SQLiteDatabaseHelper.columnTo];
          if ((message.envelope?.to == null || (message.envelope!.to?.isEmpty ?? true)) && toRow != null) {
            final toString = toRow.toString();
            if (toString.isNotEmpty) {
              final parts = toString.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
              message.envelope!.to = parts.map((email) => MailAddress('', email)).toList();
            }
          }
        } catch (_) {}
        
        // CRITICAL FIX: Ensure envelope date is properly set from database if missing
        if (message.envelope?.date == null) {
          final dateValue = row[SQLiteDatabaseHelper.columnDate];
          if (dateValue != null) {
            try {
              final dateMillis = dateValue is int ? dateValue : int.tryParse(dateValue.toString());
              if (dateMillis != null) {
                message.envelope!.date = DateTime.fromMillisecondsSinceEpoch(dateMillis);
                if (kDebugMode) {
                  print('📧 Set envelope date from database: ${message.envelope!.date}');
                }
              }
            } catch (e) {
              if (kDebugMode) {
                print('📧 Error setting envelope date: $e');
              }
            }
          }
        }

        // Also hydrate top-level from if missing so detail views work consistently
        try {
          if ((message.from == null || message.from!.isEmpty) && (message.envelope?.from?.isNotEmpty ?? false)) {
            message.from = message.envelope!.from;
          }
          if ((message.to == null || message.to!.isEmpty) && (message.envelope?.to?.isNotEmpty ?? false)) {
            message.to = message.envelope!.to;
          }
        } catch (_) {}
      } catch (e) {
        if (kDebugMode) {
          print('📧 Error parsing envelope: $e');
        }
      }
    } else {
      // No envelope JSON persisted: synthesize minimal envelope and headers from denormalized columns
      try {
        final dateValue = row[SQLiteDatabaseHelper.columnDate];
        DateTime? date;
        if (dateValue != null) {
          final dateMillis = dateValue is int ? dateValue : int.tryParse(dateValue.toString());
          if (dateMillis != null) {
            date = DateTime.fromMillisecondsSinceEpoch(dateMillis);
          }
        }
        final subjRow = row[SQLiteDatabaseHelper.columnSubject]?.toString() ?? '';
        final fromRow = row[SQLiteDatabaseHelper.columnFrom]?.toString() ?? '';
        final senderName = row[SQLiteDatabaseHelper.columnSenderName]?.toString();
        if (subjRow.isNotEmpty || fromRow.isNotEmpty || date != null) {
          final env = Envelope(
            date: date,
            subject: subjRow.isNotEmpty ? subjRow : null,
            from: fromRow.isNotEmpty ? [MailAddress(senderName ?? '', fromRow)] : null,
          );
          message.envelope = env;
          // Hydrate top-level fields and headers to aid tile rendering fallbacks
          if (message.from == null || message.from!.isEmpty) {
            message.from = env.from;
          }
          if (subjRow.isNotEmpty) {
            try { message.setHeader('subject', subjRow); } catch (_) {}
          }
          try { message.setHeader('x-ready', '1'); } catch (_) {}
        }
      } catch (_) {}
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
    
    // Convert address lists with improved parsing
    if (map['from'] != null) {
      envelope.from = (map['from'] as List).map((addrData) {
        if (addrData is Map<String, dynamic>) {
          // New format: {email: "...", personalName: "..."}
          return MailAddress(
            addrData['personalName'] ?? '',
            addrData['email'] ?? '',
          );
        } else {
          // Fallback for old format: string representation
          try {
            return MailAddress.parse(addrData.toString());
          } catch (e) {
            if (kDebugMode) {
              print('📧 Error parsing address: $addrData, error: $e');
            }
            return MailAddress('', addrData.toString());
          }
        }
      }).toList();
    }
    
    if (map['to'] != null) {
      envelope.to = (map['to'] as List).map((addrData) {
        if (addrData is Map<String, dynamic>) {
          return MailAddress(
            addrData['personalName'] ?? '',
            addrData['email'] ?? '',
          );
        } else {
          try {
            return MailAddress.parse(addrData.toString());
          } catch (e) {
            return MailAddress('', addrData.toString());
          }
        }
      }).toList();
    }
    
    if (map['cc'] != null) {
      envelope.cc = (map['cc'] as List).map((addrData) {
        if (addrData is Map<String, dynamic>) {
          return MailAddress(
            addrData['personalName'] ?? '',
            addrData['email'] ?? '',
          );
        } else {
          try {
            return MailAddress.parse(addrData.toString());
          } catch (e) {
            return MailAddress('', addrData.toString());
          }
        }
      }).toList();
    }
    
    if (map['bcc'] != null) {
      envelope.bcc = (map['bcc'] as List).map((addrData) {
        if (addrData is Map<String, dynamic>) {
          return MailAddress(
            addrData['personalName'] ?? '',
            addrData['email'] ?? '',
          );
        } else {
          try {
            return MailAddress.parse(addrData.toString());
          } catch (e) {
            return MailAddress('', addrData.toString());
          }
        }
      }).toList();
    }
    
    return envelope;
  }

  /// Lightweight preview derivation used during save
  String _derivePreviewText(MimeMessage message) {
    try {
      final text = message.decodeTextPlainPart();
      if (text != null && text.isNotEmpty) {
        return _normalizePreview(text);
      }
    } catch (_) {}
    try {
      final html = message.decodeTextHtmlPart();
      if (html != null && html.isNotEmpty) {
        final stripped = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
        return _normalizePreview(stripped);
      }
    } catch (_) {}
    return '';
  }

  bool _deriveHasAttachments(MimeMessage message) {
    try {
      return message.hasAttachments();
    } catch (_) {
      return false;
    }
  }

  String _normalizePreview(String s) {
    final oneLine = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return oneLine.length > 140 ? oneLine.substring(0, 140) : oneLine;
  }

  /// Update preview_text and has_attachments for a row identified by uid or sequenceId
  Future<void> updatePreviewAndAttachments({
    required int? uid,
    required int? sequenceId,
    required String previewText,
    required bool hasAttachments,
  }) async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      final mailboxId = await _getMailboxId();

      final whereBuffer = StringBuffer('${SQLiteDatabaseHelper.columnMailboxId} = ?');
      final args = <Object?>[mailboxId];

      if (uid != null) {
        whereBuffer.write(' AND ${SQLiteDatabaseHelper.columnUid} = ?');
        args.add(uid);
      } else if (sequenceId != null) {
        whereBuffer.write(' AND ${SQLiteDatabaseHelper.columnSequenceId} = ?');
        args.add(sequenceId);
      } else {
        return;
      }

      final Map<String, Object?> updateFields = {
        SQLiteDatabaseHelper.columnHasAttachments: hasAttachments ? 1 : 0,
      };
      // Do NOT clobber existing preview with empty string
      if (previewText.trim().isNotEmpty) {
        updateFields[SQLiteDatabaseHelper.columnPreviewText] = previewText;
      }

      final count = await db.update(
        SQLiteDatabaseHelper.tableEmails,
        updateFields,
        where: whereBuffer.toString(),
        whereArgs: args,
      );

      // If no row was updated, insert a lightweight stub so hydration can succeed later
      if (count == 0) {
        final Map<String, Object?> insertMap = {
          SQLiteDatabaseHelper.columnMailboxId: mailboxId,
          // Only one of uid or sequenceId may be present; both columns are nullable
          SQLiteDatabaseHelper.columnUid: uid,
          SQLiteDatabaseHelper.columnSequenceId: sequenceId,
          SQLiteDatabaseHelper.columnPreviewText: previewText.trim().isNotEmpty ? previewText : null,
          SQLiteDatabaseHelper.columnHasAttachments: hasAttachments ? 1 : 0,
          // Mark as seen by default for Drafts to avoid unread artifacts
          SQLiteDatabaseHelper.columnIsSeen: 1,
          // Use current time so ordering is reasonable until envelope is known
          SQLiteDatabaseHelper.columnDate: DateTime.now().millisecondsSinceEpoch,
          // Minimal placeholders; envelope/meta will be filled by subsequent updates
          SQLiteDatabaseHelper.columnSubject: null,
          SQLiteDatabaseHelper.columnFrom: null,
          SQLiteDatabaseHelper.columnTo: null,
        };
        await db.insert(
          SQLiteDatabaseHelper.tableEmails,
          insertMap,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error updating preview/attachments: $e');
      }
    }
  }

  /// Update envelope JSON, subject/from/to/date and derived fields for a message row.
  /// Identified by uid or sequenceId.
  Future<void> updateEnvelopeFromMessage(MimeMessage message) async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      final mailboxId = await _getMailboxId();

      final whereBuffer = StringBuffer('${SQLiteDatabaseHelper.columnMailboxId} = ?');
      final args = <Object?>[mailboxId];

      final uid = message.uid;
      final seqId = message.sequenceId;

      if (uid != null) {
        whereBuffer.write(' AND ${SQLiteDatabaseHelper.columnUid} = ?');
        args.add(uid);
      } else if (seqId != null) {
        whereBuffer.write(' AND ${SQLiteDatabaseHelper.columnSequenceId} = ?');
        args.add(seqId);
      } else {
        return;
      }

      // Prepare envelope JSON and basic meta
      final envJson = jsonEncode(_envelopeToMap(message.envelope));
      final subj = (message.decodeSubject() ?? message.envelope?.subject ?? '').toString();
      String fromEmail = '';
      try {
        if (message.envelope?.from?.isNotEmpty == true) {
          fromEmail = message.envelope!.from!.first.email;
        } else if (message.from?.isNotEmpty == true) {
          fromEmail = message.from!.first.email;
        } else {
          final hdr = message.getHeaderValue('from');
          if (hdr != null && hdr.isNotEmpty) {
            try { fromEmail = MailAddress.parse(hdr).email; } catch (_) { fromEmail = hdr; }
          }
        }
      } catch (_) {}
      final toEmails = (message.envelope?.to ?? message.to ?? const <MailAddress>[])
          .map((a) => a.email)
          .where((e) => e.isNotEmpty)
          .join(',');
      final dateMillis = (message.decodeDate() ?? message.envelope?.date ?? DateTime.now()).millisecondsSinceEpoch;
      final senderName = _deriveSenderName(message);
      final normalizedSubject = _normalizeSubject(subj);
      final dayBucket = dateMillis ~/ 86400000;
      // Preview/attachments hints from headers if provided (e.g., realtime projection)
      final pv = message.getHeaderValue('x-preview');
      final hasAttHeader = message.getHeaderValue('x-has-attachments');
      final hasAttVal = (hasAttHeader == '1') ? 1 : (hasAttHeader == '0' ? 0 : null);

      final Map<String, Object?> data = {
        SQLiteDatabaseHelper.columnEnvelope: envJson,
        // Always keep server date and flags up-to-date
        SQLiteDatabaseHelper.columnDate: dateMillis,
        SQLiteDatabaseHelper.columnEmailFlags: message.flags?.map((f) => f.toString()).join(',') ?? '',
        SQLiteDatabaseHelper.columnIsSeen: message.isSeen ? 1 : 0,
        SQLiteDatabaseHelper.columnIsFlagged: message.isFlagged ? 1 : 0,
        SQLiteDatabaseHelper.columnIsDeleted: message.isDeleted ? 1 : 0,
        SQLiteDatabaseHelper.columnIsAnswered: message.isAnswered ? 1 : 0,
      };
      // Do not overwrite good values with empty/unknown placeholders
      if (subj.trim().isNotEmpty) {
        data[SQLiteDatabaseHelper.columnSubject] = subj;
        data[SQLiteDatabaseHelper.columnNormalizedSubject] = normalizedSubject;
      }
      if (fromEmail.trim().isNotEmpty) {
        data[SQLiteDatabaseHelper.columnFrom] = fromEmail;
        data[SQLiteDatabaseHelper.columnSenderName] = senderName;
      }
      if (toEmails.trim().isNotEmpty) {
        data[SQLiteDatabaseHelper.columnTo] = toEmails;
      }
      if ((pv ?? '').toString().trim().isNotEmpty) {
        data[SQLiteDatabaseHelper.columnPreviewText] = pv;
      }
      if (hasAttVal != null) {
        data[SQLiteDatabaseHelper.columnHasAttachments] = hasAttVal;
      }
      // Maintain day bucket with the updated date
      data[SQLiteDatabaseHelper.columnDayBucket] = dayBucket;

      final count = await db.update(
        SQLiteDatabaseHelper.tableEmails,
        data,
        where: whereBuffer.toString(),
        whereArgs: args,
      );

      // If no row updated, insert a new envelope row (upsert behavior)
      if (count == 0) {
        final Map<String, Object?> insertMap = {
          SQLiteDatabaseHelper.columnMailboxId: mailboxId,
          SQLiteDatabaseHelper.columnUid: uid,
          SQLiteDatabaseHelper.columnSequenceId: seqId,
          SQLiteDatabaseHelper.columnEnvelope: envJson,
          SQLiteDatabaseHelper.columnSubject: subj.trim().isNotEmpty ? subj : null,
          SQLiteDatabaseHelper.columnFrom: fromEmail.trim().isNotEmpty ? fromEmail : null,
          SQLiteDatabaseHelper.columnTo: toEmails.trim().isNotEmpty ? toEmails : null,
          SQLiteDatabaseHelper.columnDate: dateMillis,
          SQLiteDatabaseHelper.columnEmailFlags: message.flags?.map((f) => f.toString()).join(',') ?? '',
          SQLiteDatabaseHelper.columnIsSeen: message.isSeen ? 1 : 0,
          SQLiteDatabaseHelper.columnIsFlagged: message.isFlagged ? 1 : 0,
          SQLiteDatabaseHelper.columnIsDeleted: message.isDeleted ? 1 : 0,
          SQLiteDatabaseHelper.columnIsAnswered: message.isAnswered ? 1 : 0,
          SQLiteDatabaseHelper.columnSenderName: senderName.trim().isNotEmpty ? senderName : null,
          SQLiteDatabaseHelper.columnNormalizedSubject: normalizedSubject.trim().isNotEmpty ? normalizedSubject : null,
          SQLiteDatabaseHelper.columnDayBucket: dayBucket,
          if ((pv ?? '').toString().trim().isNotEmpty)
            SQLiteDatabaseHelper.columnPreviewText: pv,
          if (hasAttVal != null)
            SQLiteDatabaseHelper.columnHasAttachments: hasAttVal,
        };
        await db.insert(
          SQLiteDatabaseHelper.tableEmails,
          insertMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error updating envelope/meta: $e');
      }
    }
  }

  /// Backfill derived fields (sender_name, normalized_subject) for existing rows.
  /// Processes up to [maxRows] per call to avoid long-running transactions.
  Future<int> backfillDerivedFields({int maxRows = 500}) async {
    final endTrace = PerfTracer.begin('storage.backfillDerivedFields', args: {
      'mailbox': mailbox.name,
      'maxRows': maxRows,
    });
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      final mailboxId = await _getMailboxId();

      // Select rows missing derived fields (sender_name or normalized_subject)
      // Use COALESCE and TRIM to treat empty strings as missing
      final rows = await db.query(
        SQLiteDatabaseHelper.tableEmails,
        columns: [
          SQLiteDatabaseHelper.columnId,
          SQLiteDatabaseHelper.columnSubject,
          SQLiteDatabaseHelper.columnFrom,
          SQLiteDatabaseHelper.columnEnvelope,
          SQLiteDatabaseHelper.columnDate,
        ],
        where:
            '${SQLiteDatabaseHelper.columnMailboxId} = ? AND ('
            'TRIM(COALESCE(${SQLiteDatabaseHelper.columnSenderName}, "")) = "" OR '
            'TRIM(COALESCE(${SQLiteDatabaseHelper.columnNormalizedSubject}, "")) = ""'
            ')',
        whereArgs: [mailboxId],
        orderBy: '${SQLiteDatabaseHelper.columnDate} DESC',
        limit: maxRows,
      );

      if (rows.isEmpty) return 0;

      int updated = 0;
      await db.transaction((txn) async {
        final batch = txn.batch();
        for (final row in rows) {
          try {
            final id = row[SQLiteDatabaseHelper.columnId] as int;
            final subj = (row[SQLiteDatabaseHelper.columnSubject] ?? '').toString();
            final from = (row[SQLiteDatabaseHelper.columnFrom] ?? '').toString();
            String senderName = '';
            // Try derive from envelope first if present
            final envelopeJson = row[SQLiteDatabaseHelper.columnEnvelope];
            if (envelopeJson != null && envelopeJson.toString().isNotEmpty) {
              try {
                final env = _mapToEnvelope(jsonDecode(envelopeJson as String));
                senderName = (env.from?.isNotEmpty == true)
                    ? (env.from!.first.personalName?.toString().trim() ?? '')
                    : '';
              } catch (_) {}
            }
            if (senderName.isEmpty) {
              senderName = _deriveSenderNameFromRaw(from);
            }
            final normalizedSubject = _normalizeSubject(subj);

            batch.update(
              SQLiteDatabaseHelper.tableEmails,
              {
                SQLiteDatabaseHelper.columnSenderName: senderName,
                SQLiteDatabaseHelper.columnNormalizedSubject: normalizedSubject,
              },
              where: '${SQLiteDatabaseHelper.columnId} = ?',
              whereArgs: [id],
            );
            updated++;
          } catch (_) {
            // Skip problematic rows and continue
          }
        }
        await batch.commit(noResult: true);
      });

      if (kDebugMode) {
        // print('📧 Backfilled derived fields for $updated rows in mailbox ${mailbox.name}');
      }
      return updated;
    } catch (e) {
      if (kDebugMode) {
        // print('📧 Error backfilling derived fields: $e');
      }
      return 0;
    } finally {
      try { endTrace(); } catch (_) {}
    }
  }

  String _deriveSenderName(MimeMessage message) {
    try {
      final env = message.envelope;
      if (env != null && env.from?.isNotEmpty == true) {
        final name = env.from!.first.personalName?.trim();
        if (name != null && name.isNotEmpty) return name;
        final email = env.from!.first.email;
        final at = email.indexOf('@');
        return at > 0 ? email.substring(0, at) : email;
      }
      // Fallback to from header if available via getHeaderValue
      final hdr = message.getHeaderValue('from');
      if (hdr != null && hdr.isNotEmpty) {
        return _deriveSenderNameFromRaw(hdr);
      }
    } catch (_) {}
    return '';
  }

  String _deriveSenderNameFromRaw(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    // Extract name between quotes or before <email>
    final nameInQuotes = RegExp(r'"([^"]+)"').firstMatch(trimmed);
    if (nameInQuotes != null) return nameInQuotes.group(1)!.trim();
    final nameBeforeEmail = RegExp(r'^(.*?)\s*<').firstMatch(trimmed);
    if (nameBeforeEmail != null) {
      final candidate = nameBeforeEmail.group(1)!.trim();
      if (candidate.isNotEmpty) return candidate;
    }
    // Fallback to local-part of email
    final emailMatch = RegExp(r'<([^>]+)>').firstMatch(trimmed) ?? RegExp(r'([^\s@]+@[^\s@]+)').firstMatch(trimmed);
    if (emailMatch != null) {
      final email = emailMatch.group(1)!;
      final at = email.indexOf('@');
      return at > 0 ? email.substring(0, at) : email;
    }
    return trimmed; // As last resort
  }

  String _normalizeSubject(String subject) {
    var s = subject.trim().toLowerCase();
    if (s.isEmpty) return s;
    // Remove typical reply/forward prefixes repeatedly: re:, fw:, fwd:, re[2]:, etc.
    final prefix = RegExp(r'^(\s*(re(\[\d+\])?|fw|fwd)\s*:\s*)+');
    s = s.replaceFirst(prefix, '');
    // Collapse whitespace
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// Get UID bounds and count for this mailbox
  Future<SyncBounds> getUidBounds() async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      final mailboxId = await _getMailboxId();
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS cnt, MIN(${SQLiteDatabaseHelper.columnUid}) AS min_uid, MAX(${SQLiteDatabaseHelper.columnUid}) AS max_uid '
        'FROM ${SQLiteDatabaseHelper.tableEmails} WHERE ${SQLiteDatabaseHelper.columnMailboxId} = ?',
        [mailboxId],
      );
      if (rows.isEmpty) {
        return const SyncBounds(count: 0, minUid: null, maxUid: null);
      }
      final row = rows.first;
      int? asOptInt(Object? v) => v == null
          ? null
          : (v is int
              ? v
              : int.tryParse(v.toString()));
      final countVal = row['cnt'];
      final count = countVal is int ? countVal : int.tryParse(countVal.toString()) ?? 0;
      return SyncBounds(
        count: count,
        minUid: asOptInt(row['min_uid']),
        maxUid: asOptInt(row['max_uid']),
      );
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error computing UID bounds: $e');
      }
      return const SyncBounds(count: 0, minUid: null, maxUid: null);
    }
  }

  /// Read mailbox metadata (uid_next, uid_validity) as last stored in DB
  Future<MailboxMeta> getMailboxMeta() async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      final rows = await db.query(
        SQLiteDatabaseHelper.tableMailboxes,
        columns: [
          SQLiteDatabaseHelper.columnUidNext,
          SQLiteDatabaseHelper.columnUidValidity,
        ],
        where: '${SQLiteDatabaseHelper.columnName} = ? AND ${SQLiteDatabaseHelper.columnAccountEmail} = ?',
        whereArgs: [mailbox.name, mailAccount.email],
        limit: 1,
      );
      if (rows.isEmpty) return const MailboxMeta();
      final row = rows.first;
      int? asOptInt(Object? v) => v == null
          ? null
          : (v is int
              ? v
              : int.tryParse(v.toString()));
      return MailboxMeta(
        uidNext: asOptInt(row[SQLiteDatabaseHelper.columnUidNext]),
        uidValidity: asOptInt(row[SQLiteDatabaseHelper.columnUidValidity]),
      );
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error reading mailbox meta: $e');
      }
      return const MailboxMeta();
    }
  }

  /// Update mailbox metadata (uid_next, uid_validity) in DB
  Future<void> updateMailboxMeta({int? uidNext, int? uidValidity}) async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      final data = <String, Object?>{};
      if (uidNext != null) data[SQLiteDatabaseHelper.columnUidNext] = uidNext;
      if (uidValidity != null) data[SQLiteDatabaseHelper.columnUidValidity] = uidValidity;
      if (data.isEmpty) return;
      await db.update(
        SQLiteDatabaseHelper.tableMailboxes,
        data,
        where: '${SQLiteDatabaseHelper.columnName} = ? AND ${SQLiteDatabaseHelper.columnAccountEmail} = ?',
        whereArgs: [mailbox.name, mailAccount.email],
      );
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error updating mailbox meta: $e');
      }
    }
  }

  /// Get full enterprise sync state for this mailbox (v6)
  Future<MailboxSyncState> getSyncState() async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      final rows = await db.query(
        SQLiteDatabaseHelper.tableMailboxes,
        columns: [
          SQLiteDatabaseHelper.columnUidNext,
          SQLiteDatabaseHelper.columnUidValidity,
          SQLiteDatabaseHelper.columnLastSyncedUidHigh,
          SQLiteDatabaseHelper.columnLastSyncedUidLow,
          SQLiteDatabaseHelper.columnInitialSyncDone,
          SQLiteDatabaseHelper.columnHighestModSeq,
          SQLiteDatabaseHelper.columnLastSyncStartedAt,
          SQLiteDatabaseHelper.columnLastSyncFinishedAt,
        ],
        where: '${SQLiteDatabaseHelper.columnName} = ? AND ${SQLiteDatabaseHelper.columnAccountEmail} = ?',
        whereArgs: [mailbox.name, mailAccount.email],
        limit: 1,
      );
      if (rows.isEmpty) return const MailboxSyncState();
      final r = rows.first;
      int? asOptInt(Object? v) => v == null ? null : (v is int ? v : int.tryParse(v.toString()));
      bool? asOptBool(Object? v) => v == null ? null : SQLiteDatabaseHelper.intToBool(v is int ? v : int.tryParse(v.toString()) ?? 0);
      return MailboxSyncState(
        uidNext: asOptInt(r[SQLiteDatabaseHelper.columnUidNext]),
        uidValidity: asOptInt(r[SQLiteDatabaseHelper.columnUidValidity]),
        lastSyncedUidHigh: asOptInt(r[SQLiteDatabaseHelper.columnLastSyncedUidHigh]),
        lastSyncedUidLow: asOptInt(r[SQLiteDatabaseHelper.columnLastSyncedUidLow]),
        initialSyncDone: asOptBool(r[SQLiteDatabaseHelper.columnInitialSyncDone]) ?? false,
        highestModSeq: asOptInt(r[SQLiteDatabaseHelper.columnHighestModSeq]),
        lastSyncStartedAt: asOptInt(r[SQLiteDatabaseHelper.columnLastSyncStartedAt]),
        lastSyncFinishedAt: asOptInt(r[SQLiteDatabaseHelper.columnLastSyncFinishedAt]),
      );
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error reading sync state: $e');
      }
      return const MailboxSyncState();
    }
  }

  /// Update enterprise sync state (partial updates allowed)
  Future<void> updateSyncState({
    int? uidNext,
    int? uidValidity,
    int? lastSyncedUidHigh,
    int? lastSyncedUidLow,
    bool? initialSyncDone,
    int? highestModSeq,
    int? lastSyncStartedAt,
    int? lastSyncFinishedAt,
  }) async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      final data = <String, Object?>{};
      if (uidNext != null) data[SQLiteDatabaseHelper.columnUidNext] = uidNext;
      if (uidValidity != null) data[SQLiteDatabaseHelper.columnUidValidity] = uidValidity;
      if (lastSyncedUidHigh != null) data[SQLiteDatabaseHelper.columnLastSyncedUidHigh] = lastSyncedUidHigh;
      if (lastSyncedUidLow != null) data[SQLiteDatabaseHelper.columnLastSyncedUidLow] = lastSyncedUidLow;
      if (initialSyncDone != null) data[SQLiteDatabaseHelper.columnInitialSyncDone] = SQLiteDatabaseHelper.boolToInt(initialSyncDone);
      if (highestModSeq != null) data[SQLiteDatabaseHelper.columnHighestModSeq] = highestModSeq;
      if (lastSyncStartedAt != null) data[SQLiteDatabaseHelper.columnLastSyncStartedAt] = lastSyncStartedAt;
      if (lastSyncFinishedAt != null) data[SQLiteDatabaseHelper.columnLastSyncFinishedAt] = lastSyncFinishedAt;
      if (data.isEmpty) return;
      await db.update(
        SQLiteDatabaseHelper.tableMailboxes,
        data,
        where: '${SQLiteDatabaseHelper.columnName} = ? AND ${SQLiteDatabaseHelper.columnAccountEmail} = ?',
        whereArgs: [mailbox.name, mailAccount.email],
      );
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error updating sync state: $e');
      }
    }
  }

  /// Reset sync state after UIDVALIDITY change
  Future<void> resetSyncState({int? uidNext, int? uidValidity}) async {
    await updateSyncState(
      uidNext: uidNext,
      uidValidity: uidValidity,
      lastSyncedUidHigh: null,
      lastSyncedUidLow: null,
      initialSyncDone: false,
      highestModSeq: null,
      lastSyncStartedAt: DateTime.now().millisecondsSinceEpoch,
      lastSyncFinishedAt: null,
    );
  }

  /// Dispose resources
  void dispose() {
    _dataStreamController.close();
  }
}

/// Lightweight container for UID bounds and count
class SyncBounds {
  final int count;
  final int? minUid;
  final int? maxUid;
  const SyncBounds({required this.count, required this.minUid, required this.maxUid});
}

/// Lightweight container for mailbox metadata
class MailboxMeta {
  final int? uidNext;
  final int? uidValidity;
  const MailboxMeta({this.uidNext, this.uidValidity});
}

/// Enterprise-grade mailbox sync state (v6)
class MailboxSyncState {
  final int? uidNext;
  final int? uidValidity;
  final int? lastSyncedUidHigh;
  final int? lastSyncedUidLow;
  final bool initialSyncDone;
  final int? highestModSeq;
  final int? lastSyncStartedAt;
  final int? lastSyncFinishedAt;
  const MailboxSyncState({
    this.uidNext,
    this.uidValidity,
    this.lastSyncedUidHigh,
    this.lastSyncedUidLow,
    this.initialSyncDone = false,
    this.highestModSeq,
    this.lastSyncStartedAt,
    this.lastSyncFinishedAt,
  });
}

