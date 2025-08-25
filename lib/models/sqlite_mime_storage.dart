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

    try {
      // Check if mailbox exists
      final List<Map<String, dynamic>> result = await db.query(
        SQLiteDatabaseHelper.tableMailboxes,
        where: '${SQLiteDatabaseHelper.columnAccountEmail} = ? AND ${SQLiteDatabaseHelper.columnPath} = ?',
        whereArgs: [mailAccount.email, mailbox.path],
      );

      if (result.isNotEmpty) {
        // Update mailbox data
        await db.update(
          SQLiteDatabaseHelper.tableMailboxes,
          _mailboxToMap(),
          where: '${SQLiteDatabaseHelper.columnAccountEmail} = ? AND ${SQLiteDatabaseHelper.columnPath} = ?',
          whereArgs: [mailAccount.email, mailbox.path],
        );
        return result.first[SQLiteDatabaseHelper.columnId] as int;
      } else {
        // Insert new mailbox
        return await db.insert(
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

  /// Get mailbox ID from database
  Future<int> _getMailboxId() async {
    final db = await SQLiteDatabaseHelper.instance.database;

    final List<Map<String, dynamic>> result = await db.query(
      SQLiteDatabaseHelper.tableMailboxes,
      columns: [SQLiteDatabaseHelper.columnId],
      where: '${SQLiteDatabaseHelper.columnAccountEmail} = ? AND ${SQLiteDatabaseHelper.columnPath} = ?',
      whereArgs: [mailAccount.email, mailbox.path],
    );

    if (result.isEmpty) {
      return await _ensureMailboxExists();
    }

    return result.first[SQLiteDatabaseHelper.columnId] as int;
  }

  /// Save message envelopes to database
  Future<void> saveMessageEnvelopes(List<MimeMessage> messages) async {
    if (messages.isEmpty) return;

    final db = await SQLiteDatabaseHelper.instance.database;
    final mailboxId = await _getMailboxId();

    await db.transaction((txn) async {
      for (final message in messages) {
        final Map<String, dynamic> messageMap = await compute(_messageToMap, {
          'message': message,
          'mailboxId': mailboxId,
        });

        try {
          await txn.insert(
            SQLiteDatabaseHelper.tableEmails,
            messageMap,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } catch (e) {
          if (kDebugMode) {
            print('Error saving message: $e');
          }
          // Try update if insert fails
          try {
            await txn.update(
              SQLiteDatabaseHelper.tableEmails,
              messageMap,
              where: '${SQLiteDatabaseHelper.columnMailboxId} = ? AND ${SQLiteDatabaseHelper.columnUid} = ?',
              whereArgs: [mailboxId, message.uid],
            );
          } catch (e) {
            if (kDebugMode) {
              print('Error updating message: $e');
            }
          }
        }
      }
    });

    // Notify listeners
    final updatedMessages = await loadAllMessages();
    dataNotifier.value = updatedMessages;
    _dataStreamController.add(updatedMessages);
  }

  /// Load message envelopes from database for a specific sequence
  Future<List<MimeMessage>> loadMessageEnvelopes(MessageSequence sequence) async {
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
      final mailboxId = await _getMailboxId();

      final List<Map<String, dynamic>> results = await db.query(
        SQLiteDatabaseHelper.tableEmails,
        where: '${SQLiteDatabaseHelper.columnMailboxId} = ?',
        whereArgs: [mailboxId],
        orderBy: '${SQLiteDatabaseHelper.columnDate} DESC',
      );

      return await compute(_mapsToMessages, results);
    } catch (e) {
      if (kDebugMode) {
        print('Error loading all messages: $e');
      }
      return [];
    }
  }

  /// Fetch message contents - added to fix error in mail_tile.dart
  Future<MimeMessage?> fetchMessageContents(MimeMessage message) async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      final mailboxId = await _getMailboxId();

      final List<Map<String, dynamic>> results = await db.query(
        SQLiteDatabaseHelper.tableEmails,
        where: '${SQLiteDatabaseHelper.columnMailboxId} = ? AND ${SQLiteDatabaseHelper.columnUid} = ?',
        whereArgs: [mailboxId, message.uid],
      );

      if (results.isEmpty) {
        return null;
      }

      final List<MimeMessage> messages = await compute(_mapsToMessages, results);
      return messages.isNotEmpty ? messages.first : null;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching message contents: $e');
      }
      return null;
    }
  }

  /// Delete a message from database
  Future<void> deleteMessage(MimeMessage message) async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      final mailboxId = await _getMailboxId();

      await db.delete(
        SQLiteDatabaseHelper.tableEmails,
        where: '${SQLiteDatabaseHelper.columnMailboxId} = ? AND ${SQLiteDatabaseHelper.columnUid} = ?',
        whereArgs: [mailboxId, message.uid],
      );

      // Notify listeners
      final updatedMessages = await loadAllMessages();
      dataNotifier.value = updatedMessages;
      _dataStreamController.add(updatedMessages);
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting message: $e');
      }
    }
  }

  /// Delete all messages from database
  Future<void> deleteAllMessages() async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;
      final mailboxId = await _getMailboxId();

      await db.delete(
        SQLiteDatabaseHelper.tableEmails,
        where: '${SQLiteDatabaseHelper.columnMailboxId} = ?',
        whereArgs: [mailboxId],
      );

      // Notify listeners
      dataNotifier.value = [];
      _dataStreamController.add([]);
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting all messages: $e');
      }
    }
  }

  /// Clean up resources when account is removed
  Future<void> onAccountRemoved() async {
    try {
      final db = await SQLiteDatabaseHelper.instance.database;

      await db.delete(
        SQLiteDatabaseHelper.tableMailboxes,
        where: '${SQLiteDatabaseHelper.columnAccountEmail} = ?',
        whereArgs: [mailAccount.email],
      );

      // Emails will be deleted by cascade

      // Notify listeners
      dataNotifier.value = [];
      _dataStreamController.add([]);
    } catch (e) {
      if (kDebugMode) {
        print('Error removing account: $e');
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _dataStreamController.close();
  }
}

/// Helper function to convert message to map (runs in isolate)
Map<String, dynamic> _messageToMap(Map<String, dynamic> params) {
  final MimeMessage message = params['message'];
  final int mailboxId = params['mailboxId'];

  // Convert addresses to strings
  String? fromAddress;
  if (message.from != null && message.from!.isNotEmpty) {
    fromAddress = message.from!.map((addr) =>
    '${addr.personalName ?? ''} <${addr.email}>').join(', ');
  }

  String? toAddress;
  if (message.to != null && message.to!.isNotEmpty) {
    toAddress = message.to!.map((addr) =>
    '${addr.personalName ?? ''} <${addr.email}>').join(', ');
  }

  String? ccAddress;
  if (message.cc != null && message.cc!.isNotEmpty) {
    ccAddress = message.cc!.map((addr) =>
    '${addr.personalName ?? ''} <${addr.email}>').join(', ');
  }

  String? bccAddress;
  if (message.bcc != null && message.bcc!.isNotEmpty) {
    bccAddress = message.bcc!.map((addr) =>
    '${addr.personalName ?? ''} <${addr.email}>').join(', ');
  }

  // Extract content
  String? textContent = message.decodeTextPlainPart();
  String? htmlContent = message.decodeTextHtmlPart();

  // Serialize envelope for faster retrieval
  Uint8List? envelopeBytes;
  try {
    final Map<String, dynamic> envelope = {
      'uid': message.uid,
      'sequenceId': message.sequenceId,
      'subject': message.decodeSubject(),
      'from': fromAddress,
      'to': toAddress,
      'cc': ccAddress,
      'bcc': bccAddress,
      'date': message.decodeDate()?.millisecondsSinceEpoch,
      'size': message.size,
      'flags': message.flags,
      'hasAttachments': message.hasAttachments(),
    };

    envelopeBytes = Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  } catch (e) {
    // Ignore serialization errors
  }

  return {
    SQLiteDatabaseHelper.columnMailboxId: mailboxId,
    SQLiteDatabaseHelper.columnUid: message.uid,
    SQLiteDatabaseHelper.columnMessageId: message.getHeaderValue('message-id')?.replaceAll('<', '').replaceAll('>', ''),
    SQLiteDatabaseHelper.columnSubject: message.decodeSubject(),
    SQLiteDatabaseHelper.columnFrom: fromAddress,
    SQLiteDatabaseHelper.columnTo: toAddress,
    SQLiteDatabaseHelper.columnCc: ccAddress,
    SQLiteDatabaseHelper.columnBcc: bccAddress,
    SQLiteDatabaseHelper.columnDate: message.decodeDate()?.millisecondsSinceEpoch,
    SQLiteDatabaseHelper.columnContent: textContent,
    SQLiteDatabaseHelper.columnHtmlContent: htmlContent,
    SQLiteDatabaseHelper.columnIsSeen: SQLiteDatabaseHelper.boolToInt(message.isSeen),
    SQLiteDatabaseHelper.columnIsFlagged: SQLiteDatabaseHelper.boolToInt(message.isFlagged),
    SQLiteDatabaseHelper.columnIsDeleted: SQLiteDatabaseHelper.boolToInt(message.isDeleted),
    SQLiteDatabaseHelper.columnIsAnswered: SQLiteDatabaseHelper.boolToInt(message.isAnswered),
    SQLiteDatabaseHelper.columnIsDraft: SQLiteDatabaseHelper.boolToInt(false), // MimeMessage doesn't have isDraft
    SQLiteDatabaseHelper.columnIsRecent: SQLiteDatabaseHelper.boolToInt(false), // MimeMessage doesn't have isRecent
    SQLiteDatabaseHelper.columnHasAttachments: SQLiteDatabaseHelper.boolToInt(message.hasAttachments()),
    SQLiteDatabaseHelper.columnSize: message.size,
    SQLiteDatabaseHelper.columnEnvelope: envelopeBytes,
    SQLiteDatabaseHelper.columnSequenceId: message.sequenceId,
    SQLiteDatabaseHelper.columnModSeq: message.modSequence,
  };
}

/// Helper function to convert database maps to MimeMessage objects (runs in isolate)
List<MimeMessage> _mapsToMessages(List<Map<String, dynamic>> maps) {
  final List<MimeMessage> messages = [];

  for (final map in maps) {
    try {
      final MimeMessage message = MimeMessage();

      // Set basic properties
      message.uid = map[SQLiteDatabaseHelper.columnUid] as int?;
      message.sequenceId = map[SQLiteDatabaseHelper.columnSequenceId] as int?;
      message.modSequence = map[SQLiteDatabaseHelper.columnModSeq] as int?;
      message.size = map[SQLiteDatabaseHelper.columnSize] as int?;

      // Set flags
      message.isSeen = SQLiteDatabaseHelper.intToBool(map[SQLiteDatabaseHelper.columnIsSeen] as int);
      message.isFlagged = SQLiteDatabaseHelper.intToBool(map[SQLiteDatabaseHelper.columnIsFlagged] as int);
      message.isDeleted = SQLiteDatabaseHelper.intToBool(map[SQLiteDatabaseHelper.columnIsDeleted] as int);
      message.isAnswered = SQLiteDatabaseHelper.intToBool(map[SQLiteDatabaseHelper.columnIsAnswered] as int);
      // MimeMessage doesn't have isDraft or isRecent properties

      // Set headers
      final String? subject = map[SQLiteDatabaseHelper.columnSubject] as String?;
      if (subject != null) {
        message.addHeader('subject', subject);
      }

      final String? messageId = map[SQLiteDatabaseHelper.columnMessageId] as String?;
      if (messageId != null) {
        message.addHeader('message-id', '<$messageId>');
      }

      // Set addresses
      final String? fromAddress = map[SQLiteDatabaseHelper.columnFrom] as String?;
      if (fromAddress != null && fromAddress.isNotEmpty) {
        message.from = _parseAddresses(fromAddress);
      }

      final String? toAddress = map[SQLiteDatabaseHelper.columnTo] as String?;
      if (toAddress != null && toAddress.isNotEmpty) {
        message.to = _parseAddresses(toAddress);
      }

      final String? ccAddress = map[SQLiteDatabaseHelper.columnCc] as String?;
      if (ccAddress != null && ccAddress.isNotEmpty) {
        message.cc = _parseAddresses(ccAddress);
      }

      final String? bccAddress = map[SQLiteDatabaseHelper.columnBcc] as String?;
      if (bccAddress != null && bccAddress.isNotEmpty) {
        message.bcc = _parseAddresses(bccAddress);
      }

      // Set date
      final int? dateMillis = map[SQLiteDatabaseHelper.columnDate] as int?;
      if (dateMillis != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(dateMillis);
        message.addHeader('date', _formatDateForHeader(date));
      }

      // Set content
      final String? textContent = map[SQLiteDatabaseHelper.columnContent] as String?;
      final String? htmlContent = map[SQLiteDatabaseHelper.columnHtmlContent] as String?;

      if (htmlContent != null && htmlContent.isNotEmpty) {
        final part = MimePart();
        part.addHeader('Content-Type', 'text/html; charset=utf-8');
        part.addHeader('Content-Transfer-Encoding', 'quoted-printable');
        part.mimeData = TextMimeData(htmlContent, containsHeader: false);
        message.addPart(part);
      }

      if (textContent != null && textContent.isNotEmpty) {
        final part = MimePart();
        part.addHeader('Content-Type', 'text/plain; charset=utf-8');
        part.addHeader('Content-Transfer-Encoding', 'quoted-printable');
        part.mimeData = TextMimeData(textContent, containsHeader: false);
        message.addPart(part);
      }

      messages.add(message);
    } catch (e) {
      if (kDebugMode) {
        print('Error converting map to message: $e');
      }
    }
  }

  return messages;
}

/// Helper function to parse addresses from string
List<MailAddress> _parseAddresses(String addressesString) {
  final List<MailAddress> addresses = [];

  final addressParts = addressesString.split(',');
  for (final part in addressParts) {
    final trimmedPart = part.trim();
    if (trimmedPart.isEmpty) continue;

    final match = RegExp(r'(.*) <(.*)>').firstMatch(trimmedPart);
    if (match != null && match.group(1)!.isNotEmpty) {
      addresses.add(MailAddress(match.group(1)!.trim(), match.group(2)!.trim()));
    } else {
      addresses.add(MailAddress('', trimmedPart.replaceAll(RegExp(r'<|>'), '').trim()));
    }
  }

  return addresses;
}

/// Helper function to format date for email header
String _formatDateForHeader(DateTime date) {
  final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  final day = days[date.weekday - 1];
  final month = months[date.month - 1];

  return '$day, ${date.day} $month ${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')} ${_formatTimeZoneOffset(date.timeZoneOffset)}';
}

/// Helper function to format timezone offset
String _formatTimeZoneOffset(Duration offset) {
  final sign = offset.isNegative ? '-' : '+';
  final hours = offset.inHours.abs().toString().padLeft(2, '0');
  final minutes = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  return '$sign$hours$minutes';
}
