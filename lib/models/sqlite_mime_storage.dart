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
            final envelopeMap = jsonDecode(envelopeJson as String);
            
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
            SQLiteDatabaseHelper.columnUidNext: mailbox.uidNext ?? 0,
            SQLiteDatabaseHelper.columnUidValidity: mailbox.uidValidity ?? 0,
            SQLiteDatabaseHelper.columnMessagesExists: mailbox.messagesExists ?? 0,
            SQLiteDatabaseHelper.columnMessagesUnseen: mailbox.messagesUnseen ?? 0,
            SQLiteDatabaseHelper.columnMessagesRecent: mailbox.messagesRecent ?? 0,
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
              SQLiteDatabaseHelper.columnEmailFlags: message.flags?.map((f) => f.toString()).join(',') ?? '',
              SQLiteDatabaseHelper.columnEnvelope: jsonEncode(_envelopeToMap(message.envelope)),
              SQLiteDatabaseHelper.columnSize: message.size ?? 0,
              SQLiteDatabaseHelper.columnDate: message.decodeDate()?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
              SQLiteDatabaseHelper.columnSubject: message.decodeSubject() ?? '',
              SQLiteDatabaseHelper.columnFrom: message.from?.isNotEmpty == true ? message.from!.first.email : '',
              SQLiteDatabaseHelper.columnTo: message.to?.map((addr) => addr.email).join(',') ?? '',
              SQLiteDatabaseHelper.columnIsSeen: message.isSeen ? 1 : 0,
              SQLiteDatabaseHelper.columnIsFlagged: message.isFlagged ? 1 : 0,
              SQLiteDatabaseHelper.columnIsDeleted: message.isDeleted ? 1 : 0,
              SQLiteDatabaseHelper.columnIsAnswered: message.isAnswered ? 1 : 0,
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

  /// Delete message envelopes from database
  Future<void> deleteMessageEnvelopes(MessageSequence sequence) async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      final mailboxId = await _getMailboxId();

      await db.transaction((txn) async {
        if (sequence.isUidSequence ?? false) {
          // Delete by UID
          for (final uid in sequence.toList()) {
            await txn.delete(
              SQLiteDatabaseHelper.tableEmails,
              where: '${SQLiteDatabaseHelper.columnMailboxId} = ? AND ${SQLiteDatabaseHelper.columnUid} = ?',
              whereArgs: [mailboxId, uid],
            );
          }
        } else {
          // Delete by sequence ID
          for (final seqId in sequence.toList()) {
            await txn.delete(
              SQLiteDatabaseHelper.tableEmails,
              where: '${SQLiteDatabaseHelper.columnMailboxId} = ? AND ${SQLiteDatabaseHelper.columnSequenceId} = ?',
              whereArgs: [mailboxId, seqId],
            );
          }
        }
      });

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
    
    // Set envelope if available
    final envelopeJson = row[SQLiteDatabaseHelper.columnEnvelope];
    if (envelopeJson != null && envelopeJson.isNotEmpty) {
      try {
        final envelopeMap = jsonDecode(envelopeJson);
        message.envelope = _mapToEnvelope(envelopeMap);
        
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

  /// Dispose resources
  void dispose() {
    _dataStreamController.close();
  }
}

