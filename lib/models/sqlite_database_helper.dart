import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

/// SQLite database helper for email storage
class SQLiteDatabaseHelper {
  static final SQLiteDatabaseHelper _instance = SQLiteDatabaseHelper._internal();
  static SQLiteDatabaseHelper get instance => _instance;

  SQLiteDatabaseHelper._internal();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Database version - increment when schema changes
  static const int _databaseVersion = 6;

  // Table names
  static const String tableEmails = 'emails';
  static const String tableMailboxes = 'mailboxes';
  static const String tableDrafts = 'drafts';

  // Common column names
  static const String columnId = 'id';
  static const String columnUid = 'uid';
  static const String columnMailboxId = 'mailbox_id';
  static const String columnAccountEmail = 'account_email';

  // Email table columns
  static const String columnMessageId = 'message_id';
  static const String columnSubject = 'subject';
  static const String columnFrom = 'from_address';
  static const String columnTo = 'to_address';
  static const String columnCc = 'cc_address';
  static const String columnBcc = 'bcc_address';
  static const String columnDate = 'date';
  static const String columnContent = 'content';
  static const String columnHtmlContent = 'html_content';
  static const String columnPreviewText = 'preview_text';
  static const String columnIsSeen = 'is_seen';
  static const String columnIsFlagged = 'is_flagged';
  static const String columnIsDeleted = 'is_deleted';
  static const String columnIsAnswered = 'is_answered';
  static const String columnIsDraft = 'is_draft';
  static const String columnIsRecent = 'is_recent';
  static const String columnHasAttachments = 'has_attachments';
  static const String columnSize = 'size';
  static const String columnEnvelope = 'envelope';
  static const String columnSequenceId = 'sequence_id';
  static const String columnModSeq = 'mod_seq';
  static const String columnEmailFlags = 'flags';
  // Derived columns (v5)
  static const String columnSenderName = 'sender_name';
  static const String columnNormalizedSubject = 'normalized_subject';
  static const String columnDayBucket = 'day_bucket';

  // Mailbox table columns
  static const String columnName = 'name';
  static const String columnPath = 'path';
  static const String columnFlags = 'flags';
  static const String columnPathSeparator = 'path_separator';
  static const String columnHasChildren = 'has_children';
  static const String columnMessagesExists = 'messages_exists';
  static const String columnMessagesRecent = 'messages_recent';
  static const String columnMessagesUnseen = 'messages_unseen';
  static const String columnUidNext = 'uid_next';
  static const String columnUidValidity = 'uid_validity';
  // Enterprise-grade sync state (v6)
  static const String columnLastSyncedUidHigh = 'last_synced_uid_high';
  static const String columnLastSyncedUidLow = 'last_synced_uid_low';
  static const String columnInitialSyncDone = 'initial_sync_done';
  static const String columnHighestModSeq = 'highest_mod_seq';
  static const String columnLastSyncStartedAt = 'last_sync_started_at';
  static const String columnLastSyncFinishedAt = 'last_sync_finished_at';

  // Draft table columns
  static const String columnBody = 'body';
  static const String columnIsHtml = 'is_html';
  static const String columnAttachmentPaths = 'attachment_paths';
  static const String columnCreatedAt = 'created_at';
  static const String columnUpdatedAt = 'updated_at';
  static const String columnIsScheduled = 'is_scheduled';
  static const String columnScheduledFor = 'scheduled_for';
  static const String columnVersion = 'version';
  static const String columnCategory = 'category';
  static const String columnPriority = 'priority';
  static const String columnIsSynced = 'is_synced';
  static const String columnServerUid = 'server_uid';
  static const String columnIsDirty = 'is_dirty';
  static const String columnTags = 'tags';
  static const String columnLastError = 'last_error';

  Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), 'wahda_mail.db');

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        // Enable WAL for better write concurrency and reduce fsync stalls
        await db.rawQuery('PRAGMA journal_mode=WAL');
        await db.rawQuery('PRAGMA synchronous=NORMAL');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create mailboxes table
    await db.execute('''
      CREATE TABLE $tableMailboxes (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnAccountEmail TEXT NOT NULL,
        $columnName TEXT NOT NULL,
        $columnPath TEXT NOT NULL,
        $columnFlags TEXT,
        $columnPathSeparator TEXT,
        $columnHasChildren INTEGER,
        $columnMessagesExists INTEGER,
        $columnMessagesRecent INTEGER,
        $columnMessagesUnseen INTEGER,
        $columnUidNext INTEGER,
        $columnUidValidity INTEGER,
        $columnLastSyncedUidHigh INTEGER,
        $columnLastSyncedUidLow INTEGER,
        $columnInitialSyncDone INTEGER DEFAULT 0,
        $columnHighestModSeq INTEGER,
        $columnLastSyncStartedAt INTEGER,
        $columnLastSyncFinishedAt INTEGER,
        UNIQUE($columnAccountEmail, $columnPath)
      )
    ''');

    // Create emails table
    await db.execute('''
      CREATE TABLE $tableEmails (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnUid INTEGER,
        $columnMailboxId INTEGER NOT NULL,
        $columnMessageId TEXT,
        $columnSubject TEXT,
        $columnFrom TEXT,
        $columnTo TEXT,
        $columnCc TEXT,
        $columnBcc TEXT,
        $columnDate INTEGER,
        $columnContent TEXT,
        $columnHtmlContent TEXT,
        $columnPreviewText TEXT,
        $columnIsSeen INTEGER DEFAULT 0,
        $columnIsFlagged INTEGER DEFAULT 0,
        $columnIsDeleted INTEGER DEFAULT 0,
        $columnIsAnswered INTEGER DEFAULT 0,
        $columnIsDraft INTEGER DEFAULT 0,
        $columnIsRecent INTEGER DEFAULT 0,
        $columnHasAttachments INTEGER DEFAULT 0,
        $columnSize INTEGER,
        $columnEnvelope BLOB,
        $columnSequenceId INTEGER,
        $columnModSeq INTEGER,
        $columnEmailFlags TEXT,
        $columnSenderName TEXT,
        $columnNormalizedSubject TEXT,
        $columnDayBucket INTEGER,
        FOREIGN KEY ($columnMailboxId) REFERENCES $tableMailboxes($columnId) ON DELETE CASCADE,
        UNIQUE($columnMailboxId, $columnUid)
      )
    ''');

    // Create drafts table
    await db.execute('''
      CREATE TABLE $tableDrafts (
        $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
        $columnMessageId TEXT,
        $columnSubject TEXT,
        $columnBody TEXT,
        $columnIsHtml INTEGER DEFAULT 0,
        $columnTo TEXT,
        $columnCc TEXT,
        $columnBcc TEXT,
        $columnAttachmentPaths TEXT,
        $columnCreatedAt INTEGER,
        $columnUpdatedAt INTEGER,
        $columnIsScheduled INTEGER DEFAULT 0,
        $columnScheduledFor INTEGER,
        $columnVersion INTEGER DEFAULT 1,
        $columnCategory TEXT DEFAULT 'default',
        $columnPriority INTEGER DEFAULT 0,
        $columnIsSynced INTEGER DEFAULT 0,
        $columnServerUid INTEGER,
        $columnIsDirty INTEGER DEFAULT 1,
        $columnTags TEXT,
        $columnLastError TEXT
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_emails_mailbox_id ON $tableEmails($columnMailboxId)');
    await db.execute('CREATE INDEX idx_emails_date ON $tableEmails($columnDate)');
    await db.execute('CREATE INDEX idx_emails_uid ON $tableEmails($columnUid)');
    await db.execute('CREATE INDEX idx_emails_seen ON $tableEmails($columnIsSeen)');
    await db.execute('CREATE INDEX idx_mailboxes_account ON $tableMailboxes($columnAccountEmail)');
    // Additional performance indexes
    await db.execute('CREATE INDEX idx_emails_sequence_id ON $tableEmails($columnSequenceId)');
    await db.execute('CREATE INDEX idx_emails_mailbox_date ON $tableEmails($columnMailboxId, $columnDate)');
    // Derived-field indexes (v5)
    await db.execute('CREATE INDEX idx_emails_mailbox_day_bucket ON $tableEmails($columnMailboxId, $columnDayBucket)');
    await db.execute('CREATE INDEX idx_emails_mailbox_sender ON $tableEmails($columnMailboxId, $columnSenderName)');
    await db.execute('CREATE INDEX idx_emails_mailbox_norm_subject ON $tableEmails($columnMailboxId, $columnNormalizedSubject)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations for future versions
    if (oldVersion < 2) {
      // Add flags column to emails table (version 1 -> 2)
      await db.execute('ALTER TABLE $tableEmails ADD COLUMN $columnEmailFlags TEXT');
      if (kDebugMode) {
        print('📧 Database upgraded: Added flags column to emails table');
      }
    }
    if (oldVersion < 3) {
      // Add preview_text column and performance indexes
      await db.execute('ALTER TABLE $tableEmails ADD COLUMN $columnPreviewText TEXT');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_emails_sequence_id ON $tableEmails($columnSequenceId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_emails_mailbox_date ON $tableEmails($columnMailboxId, $columnDate)');
      if (kDebugMode) {
        print('📧 Database upgraded: Added preview_text column and new indexes');
      }
    }
    if (oldVersion < 4) {
      // Ensure has_attachments column exists (older installs may miss it)
      final columns = await db.rawQuery('PRAGMA table_info($tableEmails)');
      final hasAtt = columns.any((row) => row['name'] == columnHasAttachments);
      if (!hasAtt) {
        await db.execute('ALTER TABLE $tableEmails ADD COLUMN $columnHasAttachments INTEGER DEFAULT 0');
        if (kDebugMode) {
          print('📧 Database upgraded: Added has_attachments column');
        }
      }
      // Recreate performance indexes defensively
      await db.execute('CREATE INDEX IF NOT EXISTS idx_emails_sequence_id ON $tableEmails($columnSequenceId)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_emails_mailbox_date ON $tableEmails($columnMailboxId, $columnDate)');
    }
    if (oldVersion < 5) {
      // Add derived columns if not present
      final columns = await db.rawQuery('PRAGMA table_info($tableEmails)');
      final hasSender = columns.any((row) => row['name'] == columnSenderName);
      final hasNormSubj = columns.any((row) => row['name'] == columnNormalizedSubject);
      final hasDayBucket = columns.any((row) => row['name'] == columnDayBucket);
      if (!hasSender) {
        await db.execute('ALTER TABLE $tableEmails ADD COLUMN $columnSenderName TEXT');
      }
      if (!hasNormSubj) {
        await db.execute('ALTER TABLE $tableEmails ADD COLUMN $columnNormalizedSubject TEXT');
      }
      if (!hasDayBucket) {
        await db.execute('ALTER TABLE $tableEmails ADD COLUMN $columnDayBucket INTEGER');
      }
      // Lightweight SQL backfill for day_bucket only (computed from date)
      await db.execute('UPDATE $tableEmails SET $columnDayBucket = CASE WHEN $columnDate IS NOT NULL THEN ($columnDate / 86400000) ELSE NULL END');
      // Create indexes for derived columns
      await db.execute('CREATE INDEX IF NOT EXISTS idx_emails_mailbox_day_bucket ON $tableEmails($columnMailboxId, $columnDayBucket)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_emails_mailbox_sender ON $tableEmails($columnMailboxId, $columnSenderName)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_emails_mailbox_norm_subject ON $tableEmails($columnMailboxId, $columnNormalizedSubject)');
      if (kDebugMode) {
        print('📧 Database upgraded to v5: Added derived columns and indexes');
      }
    }
    if (oldVersion < 6) {
      // Enterprise-grade sync state columns on mailboxes
      final mCols = await db.rawQuery('PRAGMA table_info($tableMailboxes)');
      Future<void> addCol(String name, String type, {String defaultClause = ''}) async {
        final exists = mCols.any((row) => row['name'] == name);
        if (!exists) {
          await db.execute('ALTER TABLE $tableMailboxes ADD COLUMN $name $type $defaultClause');
        }
      }
      await addCol(columnLastSyncedUidHigh, 'INTEGER');
      await addCol(columnLastSyncedUidLow, 'INTEGER');
      await addCol(columnInitialSyncDone, 'INTEGER', defaultClause: 'DEFAULT 0');
      await addCol(columnHighestModSeq, 'INTEGER');
      await addCol(columnLastSyncStartedAt, 'INTEGER');
      await addCol(columnLastSyncFinishedAt, 'INTEGER');
      if (kDebugMode) {
        print('📧 Database upgraded to v6: Added enterprise sync state columns');
      }
    }
  }

  // Helper method to convert boolean to integer for SQLite
  static int boolToInt(bool value) => value ? 1 : 0;

  // Helper method to convert integer to boolean from SQLite
  static bool intToBool(int value) => value == 1;

  // Close the database
  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}
