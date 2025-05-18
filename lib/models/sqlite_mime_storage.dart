import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:enough_mail/enough_mail.dart';
import 'dart:typed_data';
import 'package:wahda_bank/views/compose/models/draft_model.dart';

class SqliteMimeStorage {
  SqliteMimeStorage._init();

  static final SqliteMimeStorage instance = SqliteMimeStorage._init();
  static Database? _database;

  factory SqliteMimeStorage() => instance;

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
      version: 2, // Increased version for schema updates
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
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

    // Drafts table
    await db.execute('''
    CREATE TABLE drafts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      message_id TEXT,
      subject TEXT NOT NULL,
      body TEXT NOT NULL,
      is_html INTEGER NOT NULL,
      to_recipients TEXT NOT NULL,
      cc_recipients TEXT NOT NULL,
      bcc_recipients TEXT NOT NULL,
      attachment_paths TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      is_scheduled INTEGER NOT NULL DEFAULT 0,
      scheduled_for INTEGER
    )
    ''');

    // Contacts table for suggestions
    await db.execute('''
    CREATE TABLE contacts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT,
      email TEXT NOT NULL UNIQUE,
      frequency INTEGER NOT NULL DEFAULT 1,
      last_used INTEGER NOT NULL
    )
    ''');

    // Create indexes for faster queries
    await db.execute('CREATE INDEX idx_messages_account_mailbox ON messages(account_id, mailbox_path)');
    await db.execute('CREATE INDEX idx_messages_uid ON messages(uid)');
    await db.execute('CREATE INDEX idx_attachments_message_id ON attachments(message_id)');
    await db.execute('CREATE INDEX idx_drafts_message_id ON drafts(message_id)');
    await db.execute('CREATE INDEX idx_contacts_email ON contacts(email)');
    await db.execute('CREATE INDEX idx_contacts_frequency ON contacts(frequency DESC)');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add drafts table if upgrading from version 1
      await db.execute('''
      CREATE TABLE IF NOT EXISTS drafts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message_id TEXT,
        subject TEXT NOT NULL,
        body TEXT NOT NULL,
        is_html INTEGER NOT NULL,
        to_recipients TEXT NOT NULL,
        cc_recipients TEXT NOT NULL,
        bcc_recipients TEXT NOT NULL,
        attachment_paths TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_scheduled INTEGER NOT NULL DEFAULT 0,
        scheduled_for INTEGER
      )
      ''');

      // Add contacts table if upgrading from version 1
      await db.execute('''
      CREATE TABLE IF NOT EXISTS contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        email TEXT NOT NULL UNIQUE,
        frequency INTEGER NOT NULL DEFAULT 1,
        last_used INTEGER NOT NULL
      )
      ''');

      // Create indexes for new tables
      await db.execute('CREATE INDEX IF NOT EXISTS idx_drafts_message_id ON drafts(message_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_contacts_email ON contacts(email)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_contacts_frequency ON contacts(frequency DESC)');
    }
  }

  // Message operations
  Future<String> insertMessage(MimeMessage message, String accountId, String mailboxPath) async {
    final db = await instance.database;

    // Generate a unique ID for the message
    final id = '${accountId}_${mailboxPath}_${message.uid}';

    // Get the raw source of the message for storage
    String mimeSource = '';
    try {
      // In enough_mail 2.1.6, we need to get the raw source differently
      if (message.mimeData != null) {
        // Use the raw text representation instead of the non-existent source property
        mimeSource = message.toString();
      }
    } catch (e) {
      print('Error getting MIME source: $e');
    }

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
      'mime_source': mimeSource,
      'created_at': DateTime.now().toIso8601String(),
    };

    // Insert or replace the message
    await db.insert(
      'messages',
      messageMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Update contact suggestions from recipients
    _updateContactsFromMessage(message);

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
      print('Error parsing MIME message: $e');
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
        print('Error parsing MIME message: $e');
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
    final id = '${messageId}_${fetchId}';

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

  // Draft operations
  Future<DraftModel> saveDraft(DraftModel draft) async {
    final db = await instance.database;

    final draftMap = draft.toMap();

    int id;
    if (draft.id != null) {
      // Update existing draft
      await db.update(
        'drafts',
        draftMap,
        where: 'id = ?',
        whereArgs: [draft.id],
      );
      id = draft.id!;
    } else {
      // Insert new draft
      id = await db.insert('drafts', draftMap);
    }

    // Return updated draft with ID
    return draft.copyWith(id: id);
  }

  Future<DraftModel?> getDraft(int id) async {
    final db = await instance.database;

    final maps = await db.query(
      'drafts',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) {
      return null;
    }

    return DraftModel.fromMap(maps.first);
  }

  Future<DraftModel?> getDraftByMessageId(String messageId) async {
    final db = await instance.database;

    final maps = await db.query(
      'drafts',
      where: 'message_id = ?',
      whereArgs: [messageId],
    );

    if (maps.isEmpty) {
      return null;
    }

    return DraftModel.fromMap(maps.first);
  }

  Future<List<DraftModel>> getAllDrafts({int limit = 50, int offset = 0}) async {
    final db = await instance.database;

    final maps = await db.query(
      'drafts',
      orderBy: 'updated_at DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => DraftModel.fromMap(map)).toList();
  }

  Future<List<DraftModel>> getScheduledDrafts() async {
    final db = await instance.database;

    final maps = await db.query(
      'drafts',
      where: 'is_scheduled = 1',
      orderBy: 'scheduled_for ASC',
    );

    return maps.map((map) => DraftModel.fromMap(map)).toList();
  }

  Future<int> deleteDraft(int id) async {
    final db = await instance.database;

    return await db.delete(
      'drafts',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteDraftByMessageId(String messageId) async {
    final db = await instance.database;

    return await db.delete(
      'drafts',
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  // Contact suggestion operations
  Future<void> _updateContactsFromMessage(MimeMessage message) async {
    final db = await instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Process all recipients
    final allRecipients = [
      ...message.to ?? [],
      ...message.cc ?? [],
      ...message.bcc ?? [],
      ...message.from ?? [],
    ];

    for (final recipient in allRecipients) {
      if (recipient.email.isNotEmpty) {
        try {
          // Try to insert new contact
          await db.insert(
            'contacts',
            {
              'name': recipient.personalName ?? '',
              'email': recipient.email,
              'frequency': 1,
              'last_used': now,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );

          // If already exists, update frequency
          await db.rawUpdate(
            'UPDATE contacts SET frequency = frequency + 1, last_used = ?, name = CASE WHEN name IS NULL OR name = "" THEN ? ELSE name END WHERE email = ?',
            [now, recipient.personalName ?? '', recipient.email],
          );
        } catch (e) {
          print('Error updating contact: $e');
        }
      }
    }
  }

  Future<List<MailAddress>> getContactSuggestions({int limit = 20}) async {
    final db = await instance.database;

    final maps = await db.query(
      'contacts',
      orderBy: 'frequency DESC, last_used DESC',
      limit: limit,
    );

    return maps.map((map) {
      return MailAddress(
        map['name'] as String? ?? '',
        map['email'] as String,
      );
    }).toList();
  }

  Future<List<MailAddress>> searchContacts(String query, {int limit = 10}) async {
    final db = await instance.database;

    final maps = await db.query(
      'contacts',
      where: 'name LIKE ? OR email LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'frequency DESC, last_used DESC',
      limit: limit,
    );

    return maps.map((map) {
      return MailAddress(
        map['name'] as String? ?? '',
        map['email'] as String,
      );
    }).toList();
  }

  // Migration from Hive
  Future<void> migrateFromHive(String accountId, String mailboxPath, List<MimeMessage> messages) async {
    final db = await instance.database;

    // Begin transaction for better performance
    await db.transaction((txn) async {
      for (final message in messages) {
        final messageId = '${accountId}_${mailboxPath}_${message.uid}';

        // Get the raw source of the message for storage
        String mimeSource = '';
        try {
          // In enough_mail 2.1.6, we need to get the raw source differently
          mimeSource = message.toString();
        } catch (e) {
          print('Error getting MIME source: $e');
        }

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
          'mime_source': mimeSource,
          'created_at': DateTime.now().toIso8601String(),
        };

        await txn.insert(
          'messages',
          messageMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });

    // Update contacts after transaction
    for (final message in messages) {
      await _updateContactsFromMessage(message);
    }
  }
}
