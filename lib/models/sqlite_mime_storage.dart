import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
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
      version: 3, // Increased version for enhanced draft schema
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

    // Enhanced drafts table with additional fields
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
      scheduled_for INTEGER,
      version INTEGER NOT NULL DEFAULT 1,
      category TEXT NOT NULL DEFAULT 'default',
      priority INTEGER NOT NULL DEFAULT 0,
      is_synced INTEGER NOT NULL DEFAULT 0,
      server_uid INTEGER,
      is_dirty INTEGER NOT NULL DEFAULT 1,
      tags TEXT,
      last_error TEXT
    )
    ''');

    // Draft versions table for history tracking
    await db.execute('''
    CREATE TABLE draft_versions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      draft_id INTEGER NOT NULL,
      version INTEGER NOT NULL,
      subject TEXT NOT NULL,
      body TEXT NOT NULL,
      is_html INTEGER NOT NULL,
      to_recipients TEXT NOT NULL,
      cc_recipients TEXT NOT NULL,
      bcc_recipients TEXT NOT NULL,
      attachment_paths TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (draft_id) REFERENCES drafts (id) ON DELETE CASCADE
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
    await db.execute('CREATE INDEX idx_drafts_category ON drafts(category)');
    await db.execute('CREATE INDEX idx_drafts_is_scheduled ON drafts(is_scheduled, scheduled_for)');
    await db.execute('CREATE INDEX idx_draft_versions_draft_id ON draft_versions(draft_id, version DESC)');
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

    if (oldVersion < 3) {
      // Add new columns to drafts table for enhanced features
      await db.execute('ALTER TABLE drafts ADD COLUMN version INTEGER NOT NULL DEFAULT 1');
      await db.execute('ALTER TABLE drafts ADD COLUMN category TEXT NOT NULL DEFAULT "default"');
      await db.execute('ALTER TABLE drafts ADD COLUMN priority INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE drafts ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE drafts ADD COLUMN server_uid INTEGER');
      await db.execute('ALTER TABLE drafts ADD COLUMN is_dirty INTEGER NOT NULL DEFAULT 1');
      await db.execute('ALTER TABLE drafts ADD COLUMN tags TEXT');
      await db.execute('ALTER TABLE drafts ADD COLUMN last_error TEXT');

      // Create draft versions table for history tracking
      await db.execute('''
      CREATE TABLE IF NOT EXISTS draft_versions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        draft_id INTEGER NOT NULL,
        version INTEGER NOT NULL,
        subject TEXT NOT NULL,
        body TEXT NOT NULL,
        is_html INTEGER NOT NULL,
        to_recipients TEXT NOT NULL,
        cc_recipients TEXT NOT NULL,
        bcc_recipients TEXT NOT NULL,
        attachment_paths TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (draft_id) REFERENCES drafts (id) ON DELETE CASCADE
      )
      ''');

      // Create new indexes for enhanced draft features
      await db.execute('CREATE INDEX IF NOT EXISTS idx_drafts_category ON drafts(category)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_drafts_is_scheduled ON drafts(is_scheduled, scheduled_for)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_draft_versions_draft_id ON draft_versions(draft_id, version DESC)');
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

  // Draft operations with enhanced features
// Fix for sqlite_mime_storage.dart
  Future<DraftModel> saveDraft(DraftModel draft) async {
    final db = await instance.database;
    final now = DateTime.now();

    // Create a copy with updated timestamp and clean state
    final updatedDraft = draft.copyWith(
      updatedAt: now,
      isDirty: false,
    );

    final draftMap = updatedDraft.toMap();

    // Initialize id with a default value
    int id = draft.id ?? -1;

    await db.transaction((txn) async {
      if (draft.id != null) {
        // Update existing draft
        await txn.update(
          'drafts',
          draftMap,
          where: 'id = ?',
          whereArgs: [draft.id],
        );
        id = draft.id!;

        // Save version history if version changed
        if (draft.version > 1) {
          await _saveDraftVersion(txn, draft);
        }
      } else {
        // Insert new draft
        id = await txn.insert('drafts', draftMap);
      }
    });

    // Return updated draft with ID
    return updatedDraft.copyWith(id: id);
  }

  // Save draft version for history tracking
  Future<void> _saveDraftVersion(Transaction txn, DraftModel draft) async {
    if (draft.id == null) return;

    await txn.insert('draft_versions', {
      'draft_id': draft.id,
      'version': draft.version,
      'subject': draft.subject,
      'body': draft.body,
      'is_html': draft.isHtml ? 1 : 0,
      'to_recipients': draft.to.join('||'),
      'cc_recipients': draft.cc.join('||'),
      'bcc_recipients': draft.bcc.join('||'),
      'attachment_paths': draft.attachmentPaths.join('||'),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
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

  Future<List<DraftModel>> getAllDrafts({
    int limit = 50,
    int offset = 0,
    String? category,
    bool? isScheduled,
    bool? isDirty,
  }) async {
    final db = await instance.database;

    // Build where clause based on filters
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (category != null) {
      whereClause += 'category = ?';
      whereArgs.add(category);
    }

    if (isScheduled != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'is_scheduled = ?';
      whereArgs.add(isScheduled ? 1 : 0);
    }

    if (isDirty != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'is_dirty = ?';
      whereArgs.add(isDirty ? 1 : 0);
    }

    final maps = await db.query(
      'drafts',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'updated_at DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => DraftModel.fromMap(map)).toList();
  }

  Future<List<DraftModel>> getScheduledDrafts() async {
    final db = await instance.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final maps = await db.query(
      'drafts',
      where: 'is_scheduled = 1 AND scheduled_for <= ?',
      whereArgs: [now],
      orderBy: 'scheduled_for ASC',
    );

    return maps.map((map) => DraftModel.fromMap(map)).toList();
  }

  Future<List<DraftModel>> getDraftsByCategory(String category) async {
    final db = await instance.database;

    final maps = await db.query(
      'drafts',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'updated_at DESC',
    );

    return maps.map((map) => DraftModel.fromMap(map)).toList();
  }

  Future<List<DraftModel>> searchDrafts(String query) async {
    final db = await instance.database;

    final maps = await db.query(
      'drafts',
      where: 'subject LIKE ? OR body LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'updated_at DESC',
    );

    return maps.map((map) => DraftModel.fromMap(map)).toList();
  }

  Future<List<DraftModel>> getDirtyDrafts() async {
    final db = await instance.database;

    final maps = await db.query(
      'drafts',
      where: 'is_dirty = 1',
      orderBy: 'updated_at DESC',
    );

    return maps.map((map) => DraftModel.fromMap(map)).toList();
  }

  Future<int> deleteDraft(int id) async {
    final db = await instance.database;

    return await db.transaction((txn) async {
      // Delete draft versions first
      await txn.delete(
        'draft_versions',
        where: 'draft_id = ?',
        whereArgs: [id],
      );

      // Then delete the draft
      return await txn.delete(
        'drafts',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<int> deleteDraftByMessageId(String messageId) async {
    final db = await instance.database;

    // First get the draft to find its ID
    final draft = await getDraftByMessageId(messageId);
    if (draft == null || draft.id == null) {
      return 0;
    }

    return await deleteDraft(draft.id!);
  }

  Future<List<Map<String, dynamic>>> getDraftVersionHistory(int draftId) async {
    final db = await instance.database;

    return await db.query(
      'draft_versions',
      where: 'draft_id = ?',
      whereArgs: [draftId],
      orderBy: 'version DESC',
    );
  }

  Future<DraftModel?> restoreDraftVersion(int draftId, int version) async {
    final db = await instance.database;

    final versionMaps = await db.query(
      'draft_versions',
      where: 'draft_id = ? AND version = ?',
      whereArgs: [draftId, version],
    );

    if (versionMaps.isEmpty) {
      return null;
    }

    final versionMap = versionMaps.first;

    // Get current draft
    final currentDraft = await getDraft(draftId);
    if (currentDraft == null) {
      return null;
    }

    // Create restored draft with version data but keep metadata
    final restoredDraft = currentDraft.copyWith(
      subject: versionMap['subject'] as String,
      body: versionMap['body'] as String,
      isHtml: versionMap['is_html'] == 1,
      to: (versionMap['to_recipients'] as String).split('||'),
      cc: (versionMap['cc_recipients'] as String).split('||'),
      bcc: (versionMap['bcc_recipients'] as String).split('||'),
      attachmentPaths: (versionMap['attachment_paths'] as String).split('||'),
      version: currentDraft.version + 1, // Increment version
      isDirty: true, // Mark as dirty
      updatedAt: DateTime.now(),
    );

    // Save the restored draft
    return await saveDraft(restoredDraft);
  }

  Future<int> markDraftSynced(int id, int serverUid) async {
    final db = await instance.database;

    return await db.update(
      'drafts',
      {
        'is_synced': 1,
        'server_uid': serverUid,
        'is_dirty': 0,
        'last_error': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markDraftSyncError(int id, String error) async {
    final db = await instance.database;

    return await db.update(
      'drafts',
      {
        'is_synced': 0,
        'last_error': error,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateDraftCategory(int id, String category) async {
    final db = await instance.database;

    return await db.update(
      'drafts',
      {'category': category},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateDraftTags(int id, List<String> tags) async {
    final db = await instance.database;

    return await db.update(
      'drafts',
      {'tags': tags.join('||')},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> batchDeleteDrafts(List<int> ids) async {
    final db = await instance.database;

    return await db.transaction((txn) async {
      // Delete draft versions first
      await txn.delete(
        'draft_versions',
        where: 'draft_id IN (${ids.map((_) => '?').join(', ')})',
        whereArgs: ids,
      );

      // Then delete the drafts
      return await txn.delete(
        'drafts',
        where: 'id IN (${ids.map((_) => '?').join(', ')})',
        whereArgs: ids,
      );
    });
  }

  Future<int> batchUpdateDraftCategory(List<int> ids, String category) async {
    final db = await instance.database;

    return await db.update(
      'drafts',
      {'category': category},
      where: 'id IN (${ids.map((_) => '?').join(', ')})',
      whereArgs: ids,
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

  Future<List<MailAddress>> getContactSuggestions() async {
    try {
      final storage = Get.find<SqliteMimeStorage>();
      return await storage.getContactSuggestions();
    } catch (error) {
      debugPrint('Error getting contact suggestions: $error');
      return <MailAddress>[];
    }
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
}
