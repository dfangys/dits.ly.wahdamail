import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';

class OfflineMimeStorage {
  static final OfflineMimeStorage instance = OfflineMimeStorage._init();
  static Database? _database;

  OfflineMimeStorage._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mime_messages.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const blobType = 'BLOB';
    const intType = 'INTEGER NOT NULL';
    const boolType = 'INTEGER NOT NULL'; // SQLite doesn't have boolean type

    // Messages table
    await db.execute('''
    CREATE TABLE messages (
      id $idType,
      account_id $textType,
      mailbox_path $textType,
      sequence_id $intType,
      uid $intType,
      subject $textType,
      from_email $textType,
      to_email $textType,
      cc_email $textType,
      bcc_email $textType,
      date $textType,
      size $intType,
      is_seen $boolType,
      is_flagged $boolType,
      is_answered $boolType,
      is_forwarded $boolType,
      has_attachments $boolType,
      mime_source $textType,
      created_at $textType
    )
    ''');

    // Attachments table
    await db.execute('''
    CREATE TABLE attachments (
      id $idType,
      message_id $textType,
      file_name $textType,
      content_type $textType,
      size $intType,
      content $blobType,
      fetch_id $textType,
      created_at $textType,
      FOREIGN KEY (message_id) REFERENCES messages (id) ON DELETE CASCADE
    )
    ''');

    // Create indexes for faster queries
    await db.execute('CREATE INDEX idx_messages_account_mailbox ON messages(account_id, mailbox_path)');
    await db.execute('CREATE INDEX idx_messages_uid ON messages(uid)');
    await db.execute('CREATE INDEX idx_attachments_message_id ON attachments(message_id)');
  }

  // Message operations
  Future<String> insertMessage(MimeMessage message, String accountId, String mailboxPath) async {
    final db = await instance.database;
    
    // Generate a unique ID for the message
    final id = '${accountId}_${mailboxPath}_${message.uid}';
    
    // Convert message to map
    final messageMap = {
      'id': id,
      'account_id': accountId,
      'mailbox_path': mailboxPath,
      'sequence_id': message.sequenceId ?? 0,
      'uid': message.uid ?? 0,
      'subject': message.decodeSubject() ?? '',
      'from_email': message.fromEmail ?? '',
      'to_email': message.to != null ? message.to!.map((e) => e.email).join(', ') : '',
      'cc_email': message.cc != null ? message.cc!.map((e) => e.email).join(', ') : '',
      'bcc_email': message.bcc != null ? message.bcc!.map((e) => e.email).join(', ') : '',
      'date': message.decodeDate()?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'size': message.size ?? 0,
      'is_seen': message.isSeen ? 1 : 0,
      'is_flagged': message.isFlagged ? 1 : 0,
      'is_answered': message.isAnswered ? 1 : 0,
      'is_forwarded': message.isForwarded ? 1 : 0,
      'has_attachments': message.hasAttachments() ? 1 : 0,
      'mime_source': message.mimeData ?? '',
      'created_at': DateTime.now().toIso8601String(),
    };
    
    // Insert or replace the message
    await db.insert(
      'messages',
      messageMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    return id;
  }

  Future<MimeMessage?> getMessage(String id) async {
    final db = await instance.database;
    
    final maps = await db.query(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isEmpty) {
      return null;
    }
    
    // Convert map to MimeMessage
    final messageMap = maps.first;
    final mimeSource = messageMap['mime_source'] as String;
    
    if (mimeSource.isEmpty) {
      return null;
    }
    
    try {
      return MimeMessage.parseFromText(mimeSource);
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing MIME message: $e');
      }
      return null;
    }
  }

  Future<List<MimeMessage>> getMessages(String accountId, String mailboxPath, {int limit = 50, int offset = 0}) async {
    final db = await instance.database;
    
    final maps = await db.query(
      'messages',
      where: 'account_id = ? AND mailbox_path = ?',
      whereArgs: [accountId, mailboxPath],
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
    
    return maps.map((map) {
      final mimeSource = map['mime_source'] as String;
      try {
        return MimeMessage.parseFromText(mimeSource);
      } catch (e) {
        if (kDebugMode) {
          print('Error parsing MIME message: $e');
        }
        return null;
      }
    }).where((message) => message != null).cast<MimeMessage>().toList();
  }

  Future<int> deleteMessage(String id) async {
    final db = await instance.database;
    
    return await db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteMessages(String accountId, String mailboxPath) async {
    final db = await instance.database;
    
    return await db.delete(
      'messages',
      where: 'account_id = ? AND mailbox_path = ?',
      whereArgs: [accountId, mailboxPath],
    );
  }

  // Attachment operations
  Future<String> insertAttachment(String messageId, String fileName, String contentType, int size, Uint8List content, String fetchId) async {
    final db = await instance.database;
    
    // Generate a unique ID for the attachment
    final id = '${messageId}_$fetchId';
    
    final attachmentMap = {
      'id': id,
      'message_id': messageId,
      'file_name': fileName,
      'content_type': contentType,
      'size': size,
      'content': content,
      'fetch_id': fetchId,
      'created_at': DateTime.now().toIso8601String(),
    };
    
    await db.insert(
      'attachments',
      attachmentMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    
    return id;
  }

  Future<Map<String, dynamic>?> getAttachment(String id) async {
    final db = await instance.database;
    
    final maps = await db.query(
      'attachments',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    if (maps.isEmpty) {
      return null;
    }
    
    return maps.first;
  }

  Future<List<Map<String, dynamic>>> getAttachments(String messageId) async {
    final db = await instance.database;
    
    return await db.query(
      'attachments',
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  Future<int> deleteAttachment(String id) async {
    final db = await instance.database;
    
    return await db.delete(
      'attachments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAttachments(String messageId) async {
    final db = await instance.database;
    
    return await db.delete(
      'attachments',
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  // Migration from Hive
  Future<void> migrateFromHive(String accountId, String mailboxPath, List<MimeMessage> messages) async {
    final db = await instance.database;
    
    // Begin transaction for better performance
    await db.transaction((txn) async {
      for (final message in messages) {
        final messageId = '${accountId}_${mailboxPath}_${message.uid}';
        
        // Insert message
        final messageMap = {
          'id': messageId,
          'account_id': accountId,
          'mailbox_path': mailboxPath,
          'sequence_id': message.sequenceId ?? 0,
          'uid': message.uid ?? 0,
          'subject': message.decodeSubject() ?? '',
          'from_email': message.fromEmail ?? '',
          'to_email': message.to != null ? message.to!.map((e) => e.email).join(', ') : '',
          'cc_email': message.cc != null ? message.cc!.map((e) => e.email).join(', ') : '',
          'bcc_email': message.bcc != null ? message.bcc!.map((e) => e.email).join(', ') : '',
          'date': message.decodeDate()?.toIso8601String() ?? DateTime.now().toIso8601String(),
          'size': message.size ?? 0,
          'is_seen': message.isSeen ? 1 : 0,
          'is_flagged': message.isFlagged ? 1 : 0,
          'is_answered': message.isAnswered ? 1 : 0,
          'is_forwarded': message.isForwarded ? 1 : 0,
          'has_attachments': message.hasAttachments() ? 1 : 0,
          'mime_source': message.mimeData ?? '',
          'created_at': DateTime.now().toIso8601String(),
        };
        
        await txn.insert(
          'messages',
          messageMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        
        // Process attachments if any
        if (message.hasAttachments()) {
          final contentInfo = message.findContentInfo();
          
          for (final info in contentInfo) {
            final mimePart = message.getPart(info.fetchId);
            
            if (mimePart != null) {
              final content = mimePart.decodeContentBinary();
              
              if (content != null) {
                final attachmentId = '${messageId}_${info.fetchId}';
                
                final attachmentMap = {
                  'id': attachmentId,
                  'message_id': messageId,
                  'file_name': info.fileName ?? 'unknown',
                  'content_type': info.mediaType?.text ?? 'application/octet-stream',
                  'size': info.size ?? 0,
                  'content': content,
                  'fetch_id': info.fetchId,
                  'created_at': DateTime.now().toIso8601String(),
                };
                
                await txn.insert(
                  'attachments',
                  attachmentMap,
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            }
          }
        }
      }
    });
  }

  // Performance optimized methods
  Future<List<Map<String, dynamic>>> getMessageHeaders(String accountId, String mailboxPath, {int limit = 50, int offset = 0}) async {
    final db = await instance.database;
    
    return await db.query(
      'messages',
      columns: ['id', 'uid', 'subject', 'from_email', 'date', 'is_seen', 'is_flagged', 'has_attachments'],
      where: 'account_id = ? AND mailbox_path = ?',
      whereArgs: [accountId, mailboxPath],
      orderBy: 'date DESC',
      limit: limit,
      offset: offset,
    );
  }

  Future<int> getMessageCount(String accountId, String mailboxPath) async {
    final db = await instance.database;
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE account_id = ? AND mailbox_path = ?',
      [accountId, mailboxPath],
    );
    
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getUnreadMessageCount(String accountId, String mailboxPath) async {
    final db = await instance.database;
    
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM messages WHERE account_id = ? AND mailbox_path = ? AND is_seen = 0',
      [accountId, mailboxPath],
    );
    
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Update message flags
  Future<int> updateMessageFlags(String id, {bool? isSeen, bool? isFlagged, bool? isAnswered, bool? isForwarded}) async {
    final db = await instance.database;
    
    final Map<String, dynamic> values = {};
    
    if (isSeen != null) values['is_seen'] = isSeen ? 1 : 0;
    if (isFlagged != null) values['is_flagged'] = isFlagged ? 1 : 0;
    if (isAnswered != null) values['is_answered'] = isAnswered ? 1 : 0;
    if (isForwarded != null) values['is_forwarded'] = isForwarded ? 1 : 0;
    
    if (values.isEmpty) return 0;
    
    return await db.update(
      'messages',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Close the database
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
