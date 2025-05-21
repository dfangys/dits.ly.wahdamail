import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sqflite/sqflite.dart';
import 'package:synchronized/synchronized.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';                 // ← for min()
import 'package:wahda_bank/views/compose/models/draft_model.dart';

/// SQLite-based storage for MIME messages with ultra-optimized performance
///
/// This class provides optimized storage and retrieval of email messages
/// using SQLite with advanced lock avoidance strategies and transaction management.
class SqliteMimeStorage {
  SqliteMimeStorage._init();

  static final SqliteMimeStorage instance = SqliteMimeStorage._init();
  static Database? _database;

  // Global lock to serialize ALL database operations
  static final _globalDbLock = Lock();

  // Separate locks for different operations to allow concurrent reads
  static final _readLock = Lock();
  static final _writeLock = Lock();
  static final _deleteLock = Lock();

  // Queue for serializing write operations
  static final _writeQueue = StreamController<_WriteOperation>();
  static bool _isWriteQueueInitialized = false;

  // Transaction management
  final _transactionLock = Lock();
  bool _isInTransaction = false;

  // Enhanced LRU cache with size limit
  final _messageCache = _LRUCache<String, MimeMessage>(500);

  // Cache invalidation timer
  Timer? _cacheInvalidationTimer;
  final _lastCacheRefresh = DateTime.now().millisecondsSinceEpoch;

  // Stream controller for message updates
  final _messageUpdateController = BehaviorSubject<_MessageUpdate>();
  Stream<_MessageUpdate> get messageUpdateStream => _messageUpdateController.stream;

  factory SqliteMimeStorage() => instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mime_messages.db');

    // Initialize write queue processor if not already done
    if (!_isWriteQueueInitialized) {
      _initWriteQueue();
      _setupCacheInvalidation();
    }

    return _database!;
  }

  // Initialize the storage - added for compatibility with enough_mail 2.1.6
  Future<void> init() async {
    await database;
  }

  // Set up periodic cache invalidation
  void _setupCacheInvalidation() {
    _cacheInvalidationTimer?.cancel();
    _cacheInvalidationTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      // Clear cache entries older than 2 hours
      final now = DateTime.now().millisecondsSinceEpoch;
      final cutoff = now - (2 * 60 * 60 * 1000); // 2 hours in milliseconds
      _messageCache.removeOlderThan(cutoff);
    });
  }

  // Initialize write queue processor
  void _initWriteQueue() {
    _isWriteQueueInitialized = true;

    // Process write operations sequentially to avoid locks
    _writeQueue.stream.listen((operation) async {
      try {
        final db = await database;

        // Use exclusive transaction for all writes
        await db.transaction((txn) async {
          await operation.execute(txn);
        }, exclusive: true);

        // Complete the operation
        operation.completer.complete(true);
      } catch (e) {
        debugPrint('Error in write queue: $e');
        operation.completer.completeError(e);
      }
    });
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getApplicationDocumentsDirectory();
    final path = join(dbPath.path, filePath);

    // Use global lock for database initialization
    return await _globalDbLock.synchronized(() async {
      final db = await openDatabase(
        path,
        version: 3, // Increased version for enhanced draft schema
        onCreate: _createDB,
        onUpgrade: _upgradeDB,
        onOpen: (db) async {
          // Optimize SQLite configuration for better performance
          if (!kIsWeb && (Platform.isAndroid || Platform.isLinux)) {
            try {
              // Set busy timeout to reduce lock warnings
              await db.execute('PRAGMA busy_timeout = 10000'); // Increased timeout

              // Enable WAL mode for better concurrency
              await db.execute('PRAGMA journal_mode = WAL');

              // Optimize for better performance
              await db.execute('PRAGMA synchronous = NORMAL');
              await db.execute('PRAGMA cache_size = 10000');
              await db.execute('PRAGMA temp_store = MEMORY');
              await db.execute('PRAGMA mmap_size = 30000000');
              await db.execute('PRAGMA page_size = 4096');

              // Set locking mode to EXCLUSIVE to prevent other connections from writing
              await db.execute('PRAGMA locking_mode = EXCLUSIVE');
            } catch (e) {
              debugPrint('Error setting PRAGMA: $e');
            }
          }
        },
      );

      return db;
    });
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
      from_name TEXT,
      to_email $textType,
      to_name TEXT,
      cc_email $textType,
      cc_name TEXT,
      bcc_email $textType,
      bcc_name TEXT,
      date $textType,
      size $intType,
      is_seen $boolType,
      is_flagged $boolType,
      is_answered $boolType,
      is_forwarded $boolType,
      is_draft $boolType DEFAULT 0,
      is_recent $boolType DEFAULT 0,
      has_attachments $boolType,
      mime_source $textType,
      created_at $textType,
      last_modified $textType
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
    await db.execute('CREATE INDEX idx_messages_date ON messages(date)');
    await db.execute('CREATE INDEX idx_messages_flags ON messages(is_seen, is_flagged, is_answered, is_forwarded)');
    await db.execute('CREATE INDEX idx_messages_from ON messages(from_email)');
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

      // Add new indexes for better performance
      await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_date ON messages(date)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_flags ON messages(is_seen, is_flagged, is_answered, is_forwarded)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_from ON messages(from_email)');

      // Add name columns to messages table if they don't exist
      try {
        await db.execute('ALTER TABLE messages ADD COLUMN from_name TEXT');
        await db.execute('ALTER TABLE messages ADD COLUMN to_name TEXT');
        await db.execute('ALTER TABLE messages ADD COLUMN cc_name TEXT');
        await db.execute('ALTER TABLE messages ADD COLUMN bcc_name TEXT');
        await db.execute('ALTER TABLE messages ADD COLUMN is_draft INTEGER NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE messages ADD COLUMN is_recent INTEGER NOT NULL DEFAULT 0');
        await db.execute('ALTER TABLE messages ADD COLUMN last_modified TEXT');
      } catch (e) {
        debugPrint('Error adding name columns: $e');
      }
    }
  }

  // Acquire transaction lock
  Future<void> _beginTransaction() async {
    await _transactionLock.synchronized(() async {
      if (!_isInTransaction) {
        final db = await database;
        await db.execute('BEGIN TRANSACTION');
        _isInTransaction = true;
      }
    });
  }

  // Commit transaction
  Future<void> _commitTransaction() async {
    await _transactionLock.synchronized(() async {
      if (_isInTransaction) {
        final db = await database;
        await db.execute('COMMIT');
        _isInTransaction = false;
      }
    });
  }

  // Rollback transaction
  Future<void> _rollbackTransaction() async {
    await _transactionLock.synchronized(() async {
      if (_isInTransaction) {
        final db = await database;
        await db.execute('ROLLBACK');
        _isInTransaction = false;
      }
    });
  }

  // Wrapper for read operations - allows concurrent reads
  Future<T> _withReadDb<T>(Future<T> Function(Database db) operation) async {
    return await _readLock.synchronized(() async {
      final db = await database;
      return await operation(db);
    });
  }

  // Wrapper for write operations - uses write queue for serialization
  Future<bool> _withWriteDb(Future<void> Function(Transaction txn) operation) async {
    final completer = Completer<bool>();

    // Add operation to write queue
    _writeQueue.add(_WriteOperation(operation, completer));

    return completer.future;
  }

  // Wrapper for transaction operations
  Future<T> _withTransaction<T>(Future<T> Function(Database db) operation) async {
    T result;

    try {
      await _beginTransaction();
      final db = await database;
      result = await operation(db);
      await _commitTransaction();
      return result;
    } catch (e) {
      await _rollbackTransaction();
      rethrow;
    }
  }

  // Message operations with optimized batching
  Future<String> insertMessage(MimeMessage message, String accountId, String mailboxPath, {Transaction? transaction}) async {
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
      debugPrint('Error getting MIME source: $e');
    }

    // Extract names from addresses
    String? fromName;
    if (message.from != null && message.from!.isNotEmpty) {
      fromName = message.from![0].personalName;
    }

    String? toName;
    if (message.to != null && message.to!.isNotEmpty) {
      toName = message.to![0].personalName;
    }

    String? ccName;
    if (message.cc != null && message.cc!.isNotEmpty) {
      ccName = message.cc![0].personalName;
    }

    String? bccName;
    if (message.bcc != null && message.bcc!.isNotEmpty) {
      bccName = message.bcc![0].personalName;
    }

    // Check if message is a draft
    bool isDraft = false;
    if (message.flags != null) {
      isDraft = message.flags!.contains(r'\Draft');
    }

    // Check if message is recent
    bool isRecent = false;
    if (message.flags != null) {
      isRecent = message.flags!.contains(r'\Recent');
    }

    // Prepare the message data
    final messageData = {
      'id': id,
      'account_id': accountId,
      'mailbox_path': mailboxPath,
      'sequence_id': message.sequenceId ?? 0,
      'uid': message.uid ?? 0,
      'subject': message.decodeSubject() ?? '',
      'from_email': message.from != null && message.from!.isNotEmpty ? message.from![0].email : '',
      'from_name': fromName,
      'to_email': message.to != null && message.to!.isNotEmpty ? message.to![0].email : '',
      'to_name': toName,
      'cc_email': message.cc != null && message.cc!.isNotEmpty ? message.cc![0].email : '',
      'cc_name': ccName,
      'bcc_email': message.bcc != null && message.bcc!.isNotEmpty ? message.bcc![0].email : '',
      'bcc_name': bccName,
      'date': message.decodeDate()?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'size': mimeSource.length,
      'is_seen': message.isSeen ? 1 : 0,
      'is_flagged': message.isFlagged ? 1 : 0,
      'is_answered': message.isAnswered ? 1 : 0,
      'is_forwarded': message.isForwarded ? 1 : 0,
      'is_draft': isDraft ? 1 : 0,
      'is_recent': isRecent ? 1 : 0,
      'has_attachments': message.hasAttachments() ? 1 : 0,
      'mime_source': mimeSource,
      'created_at': DateTime.now().toIso8601String(),
      'last_modified': DateTime.now().toIso8601String(),
    };

    // Insert or update the message
    if (transaction != null) {
      // Check if message exists
      final existing = await transaction.query(
        'messages',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (existing.isEmpty) {
        // Insert new message
        await transaction.insert('messages', messageData);
      } else {
        // Update existing message
        await transaction.update(
          'messages',
          messageData,
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    } else {
      // Use write queue for better concurrency
      await _withWriteDb((txn) async {
        // Check if message exists
        final existing = await txn.query(
          'messages',
          where: 'id = ?',
          whereArgs: [id],
        );

        if (existing.isEmpty) {
          // Insert new message
          await txn.insert('messages', messageData);
        } else {
          // Update existing message
          await txn.update(
            'messages',
            messageData,
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      });
    }

    // Update contacts from message
    _updateContactsFromMessage(message);

    // Notify about message update
    _notifyMessageUpdate(
      accountId,
      mailboxPath,
      [message],
      MessageUpdateType.update,
    );

    return id;
  }

  // Insert multiple messages in a batch

  /// Inserts or replaces messages in chunks using a Batch within a transaction.
  Future<void> insertMessageBatch(
      List<MimeMessage> messages,
      String accountId,
      String mailboxPath,
      ) async {
    if (messages.isEmpty) return;

    const chunkSize = 50;
    for (var i = 0; i < messages.length; i += chunkSize) {
      final end = min(i + chunkSize, messages.length);
      final chunk = messages.sublist(i, end);

      // Wrap each chunk in its own transaction for performance
      await _withTransaction<void>((db) async {
        final sqlBatch = db.batch();

        for (final msg in chunk) {
          final uid = msg.uid;
          if (uid == null) continue;

          final id = '${accountId}_${mailboxPath}_$uid';

          // Recompute everything you need for storage, e.g.:
          String mimeSource = msg.mimeData != null ? msg.toString() : '';
          String? fromName = msg.from?.isNotEmpty == true ? msg.from![0].personalName : null;
          // … extract toName, ccName, etc. exactly as in your single‐insert helper …

          // Draft/recent flags
          final flags = msg.flags ?? [];
          final isDraft  = flags.contains(r'\Draft') ? 1 : 0;
          final isRecent = flags.contains(r'\Recent') ? 1 : 0;

          // Build the row map
          final row = <String, Object?>{
            'id':           id,
            'account_id':   accountId,
            'mailbox_path': mailboxPath,
            'sequence_id':  msg.sequenceId ?? 0,
            'uid':          uid,
            'subject':      msg.decodeSubject() ?? '',
            'from_email':   msg.from?.first.email ?? '',
            'from_name':    fromName,
            // … to_email, to_name, cc_email, cc_name, etc. …
            'date':         msg.decodeDate()?.toIso8601String() ?? DateTime.now().toIso8601String(),
            'size':         mimeSource.length,
            'is_seen':      msg.isSeen ? 1 : 0,
            'is_flagged':   msg.isFlagged ? 1 : 0,
            'is_answered':  msg.isAnswered ? 1 : 0,
            'is_forwarded': msg.isForwarded ? 1 : 0,
            'is_draft':     isDraft,
            'is_recent':    isRecent,
            'has_attachments': msg.hasAttachments() ? 1 : 0,
            'mime_source':  mimeSource,
            'created_at':   DateTime.now().toIso8601String(),
            'last_modified': DateTime.now().toIso8601String(),
          };

          sqlBatch.insert(
            'messages',
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        await sqlBatch.commit(noResult: true);
      });

      // let the UI breathe
      await Future.delayed(Duration.zero);
    }

    // Fire a single “update” notification at the end
    _notifyMessageUpdate(
      accountId,
      mailboxPath,
      messages,
      MessageUpdateType.update,
    );
  }

  // Get message by ID
  Future<MimeMessage?> getMessageById(String id) async {
    return await _withReadDb((db) async {
      final maps = await db.query(
        'messages',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) {
        return null;
      }

      // Check cache first
      final cachedMessage = _messageCache.get(id);
      if (cachedMessage != null) {
        return cachedMessage;
      }

      // Parse message from MIME source
      final mimeSource = maps.first['mime_source'] as String?;
      if (mimeSource != null && mimeSource.isNotEmpty) {
        try {
          final message = MimeMessage.parseFromText(mimeSource);
          message.uid = maps.first['uid'] as int;
          message.sequenceId = maps.first['sequence_id'] as int;

          // Add to cache
          _messageCache.put(id, message);

          return message;
        } catch (e) {
          debugPrint('Error parsing MIME message: $e');
        }
      }

      // If parsing fails or no MIME source, create a basic message
      final message = MimeMessage();
      message.uid = maps.first['uid'] as int;
      message.sequenceId = maps.first['sequence_id'] as int;
      message.isSeen = maps.first['is_seen'] == 1;
      message.isFlagged = maps.first['is_flagged'] == 1;
      message.isAnswered = maps.first['is_answered'] == 1;
      message.isForwarded = maps.first['is_forwarded'] == 1;

      // Set flags
      message.flags = [];
      if (message.isSeen) message.flags!.add(r'\Seen');
      if (message.isFlagged) message.flags!.add(r'\Flagged');
      if (message.isAnswered) message.flags!.add(r'\Answered');
      if (maps.first['is_draft'] == 1) message.flags!.add(r'\Draft');
      if (maps.first['is_recent'] == 1) message.flags!.add(r'\Recent');

      // Add to cache
      _messageCache.put(id, message);

      return message;
    });
  }

  // Get messages by mailbox
  Future<List<MimeMessage>> getMessagesByMailbox(String accountId, String mailboxPath, {int limit = 100, int offset = 0}) async {
    return await _withReadDb((db) async {
      final maps = await db.query(
        'messages',
        where: 'account_id = ? AND mailbox_path = ?',
        whereArgs: [accountId, mailboxPath],
        orderBy: 'date DESC',
        limit: limit,
        offset: offset,
      );

      final messages = <MimeMessage>[];
      for (var map in maps) {
        final id = map['id'] as String;

        // Check cache first
        final cachedMessage = _messageCache.get(id);
        if (cachedMessage != null) {
          messages.add(cachedMessage);
          continue;
        }

        // Parse message from MIME source
        final mimeSource = map['mime_source'] as String?;
        if (mimeSource != null && mimeSource.isNotEmpty) {
          try {
            final message = MimeMessage.parseFromText(mimeSource);
            message.uid = map['uid'] as int;
            message.sequenceId = map['sequence_id'] as int;

            // Add to cache
            _messageCache.put(id, message);
            messages.add(message);
            continue;
          } catch (e) {
            debugPrint('Error parsing MIME message: $e');
          }
        }

        // If parsing fails or no MIME source, create a basic message
        final message = MimeMessage();
        message.uid = map['uid'] as int;
        message.sequenceId = map['sequence_id'] as int;
        message.isSeen = map['is_seen'] == 1;
        message.isFlagged = map['is_flagged'] == 1;
        message.isAnswered = map['is_answered'] == 1;
        message.isForwarded = map['is_forwarded'] == 1;

        // Set flags
        message.flags = [];
        if (message.isSeen) message.flags!.add(r'\Seen');
        if (message.isFlagged) message.flags!.add(r'\Flagged');
        if (message.isAnswered) message.flags!.add(r'\Answered');
        if (map['is_draft'] == 1) message.flags!.add(r'\Draft');
        if (map['is_recent'] == 1) message.flags!.add(r'\Recent');

        // Add to cache
        _messageCache.put(id, message);
        messages.add(message);
      }

      return messages;
    });
  }

  // Update message flags
  Future<void> updateMessageFlags(MimeMessage message, String accountId, String mailboxPath) async {
    final id = '${accountId}_${mailboxPath}_${message.uid}';

    // Check if message is a draft
    bool isDraft = false;
    if (message.flags != null) {
      isDraft = message.flags!.contains(r'\Draft');
    }

    // Check if message is recent
    bool isRecent = false;
    if (message.flags != null) {
      isRecent = message.flags!.contains(r'\Recent');
    }

    // Prepare the flag data
    final flagData = {
      'is_seen': message.isSeen ? 1 : 0,
      'is_flagged': message.isFlagged ? 1 : 0,
      'is_answered': message.isAnswered ? 1 : 0,
      'is_forwarded': message.isForwarded ? 1 : 0,
      'is_draft': isDraft ? 1 : 0,
      'is_recent': isRecent ? 1 : 0,
      'last_modified': DateTime.now().toIso8601String(),
    };

    // Update the message flags
    await _withWriteDb((txn) async {
      await txn.update(
        'messages',
        flagData,
        where: 'id = ?',
        whereArgs: [id],
      );
    });

    // Update cache
    final cachedMessage = _messageCache.get(id);
    if (cachedMessage != null) {
      cachedMessage.isSeen = message.isSeen;
      cachedMessage.isFlagged = message.isFlagged;
      cachedMessage.isAnswered = message.isAnswered;
      cachedMessage.isForwarded = message.isForwarded;
      cachedMessage.flags = message.flags;
    }

    // Notify about message update
    _notifyMessageUpdate(
      accountId,
      mailboxPath,
      [message],
      MessageUpdateType.flagUpdate,
    );
  }

  // Delete message
  Future<void> deleteMessage(MimeMessage message, String accountId, String mailboxPath) async {
    final id = '${accountId}_${mailboxPath}_${message.uid}';

    // Delete the message
    await _withWriteDb((txn) async {
      await txn.delete(
        'messages',
        where: 'id = ?',
        whereArgs: [id],
      );
    });

    // Remove from cache
    _messageCache.remove(id);

    // Notify about message deletion
    _notifyMessageUpdate(
      accountId,
      mailboxPath,
      [message],
      MessageUpdateType.delete,
    );
  }


  /// Batch‐update flags for multiple messages in one transaction.
  ///
  Future<void> batchUpdateMessageFlags(
      List<MimeMessage> messages,
      String accountId,
      String mailboxPath,
      ) async {
    if (messages.isEmpty) return;

    final now = DateTime.now().toIso8601String();

    // Use a single transaction for all updates
    await _withTransaction<void>((db) async {
      final sqlBatch = db.batch();

      for (final msg in messages) {
        final uid = msg.uid;
        if (uid == null) continue;

        final id = '${accountId}_${mailboxPath}_$uid';
        final flags = msg.flags ?? [];
        final isDraft  = flags.contains(r'\Draft')  ? 1 : 0;
        final isRecent = flags.contains(r'\Recent') ? 1 : 0;

        final flagData = <String, Object?>{
          'is_seen':       msg.isSeen      ? 1 : 0,
          'is_flagged':    msg.isFlagged   ? 1 : 0,
          'is_answered':   msg.isAnswered  ? 1 : 0,
          'is_forwarded':  msg.isForwarded ? 1 : 0,
          'is_draft':      isDraft,
          'is_recent':     isRecent,
          'last_modified': now,
        };

        sqlBatch.update(
          'messages',
          flagData,
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      await sqlBatch.commit(noResult: true);
    });

    // Update in-memory cache
    for (final msg in messages) {
      final uid = msg.uid;
      if (uid == null) continue;
      final id = '${accountId}_${mailboxPath}_$uid';

      final cached = _messageCache.get(id);
      if (cached != null) {
        cached.isSeen      = msg.isSeen;
        cached.isFlagged   = msg.isFlagged;
        cached.isAnswered  = msg.isAnswered;
        cached.isForwarded = msg.isForwarded;
        cached.flags       = msg.flags;
      }
    }

    // Fire a single notification for the UI
    _notifyMessageUpdate(
      accountId,
      mailboxPath,
      messages,
      MessageUpdateType.flagUpdate,
    );
  }


  // Delete multiple messages
  Future<void> deleteMessages(List<MimeMessage> messages, String accountId, String mailboxPath) async {
    if (messages.isEmpty) return;

    // Get message IDs
    final ids = messages.map((m) => '${accountId}_${mailboxPath}_${m.uid}').toList();

    // Delete the messages
    await _withWriteDb((txn) async {
      // Use placeholders for the IN clause
      final placeholders = List.filled(ids.length, '?').join(',');
      await txn.delete(
        'messages',
        where: 'id IN ($placeholders)',
        whereArgs: ids,
      );
    });

    // Remove from cache
    for (var id in ids) {
      _messageCache.remove(id);
    }

    // Notify about message deletion
    _notifyMessageUpdate(
      accountId,
      mailboxPath,
      messages,
      MessageUpdateType.delete,
    );
  }

  // Clear all messages for a mailbox
  Future<void> clearMailbox(String accountId, String mailboxPath) async {
    // Delete all messages for the mailbox
    await _withWriteDb((txn) async {
      await txn.delete(
        'messages',
        where: 'account_id = ? AND mailbox_path = ?',
        whereArgs: [accountId, mailboxPath],
      );
    });

    // Clear cache entries for this mailbox
    _messageCache.clear();

    // Notify about mailbox clear
    _notifyMessageUpdate(
      accountId,
      mailboxPath,
      [],
      MessageUpdateType.clear,
    );
  }

  // Clear all storage
  Future<void> clearStorage() async {
    // Delete all data
    await _withWriteDb((txn) async {
      await txn.delete('messages');
      await txn.delete('attachments');
      await txn.delete('drafts');
      await txn.delete('draft_versions');
    });

    // Clear cache
    _messageCache.clear();
  }

  // Notify about message updates
  void _notifyMessageUpdate(
      String accountId,
      String mailboxPath,
      List<MimeMessage> messages,
      MessageUpdateType type,
      ) {
    _messageUpdateController.add(_MessageUpdate(
      accountId: accountId,
      mailboxPath: mailboxPath,
      messages: messages,
      type: type,
    ));
  }

  // Draft operations
  Future<int> saveDraft(DraftModel draft) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Prepare the draft data
    final draftData = {
      'message_id': draft.messageId,
      'subject': draft.subject,
      'body': draft.body,
      'is_html': draft.isHtml ? 1 : 0,
      'to_recipients': draft.toRecipients.join(','),
      'cc_recipients': draft.ccRecipients.join(','),
      'bcc_recipients': draft.bccRecipients.join(','),
      'attachment_paths': draft.attachmentPaths.join(','),
      'created_at': draft.id == null ? now : null, // Only set created_at for new drafts
      'updated_at': now,
      'is_scheduled': draft.isScheduled ? 1 : 0,
      'scheduled_for': draft.scheduledFor?.millisecondsSinceEpoch,
      'version': draft.version,
      'category': draft.category,
      'priority': draft.priority,
      'is_synced': draft.isSynced ? 1 : 0,
      'server_uid': draft.serverUid,
      'is_dirty': draft.isDirty ? 1 : 0,
      'tags': draft.tags?.join(','),
      'last_error': draft.lastError,
    };

    // Remove null values
    draftData.removeWhere((key, value) => value == null);

    // int draftId;
    late int draftId;
    await _withTransaction<void>((db) async {
      if (draft.id == null) {
        // Insert new draft
        draftId = await db.insert('drafts', draftData);
      } else {
        // Update existing draft
        draftId = draft.id!;
        await db.update(
          'drafts',
          draftData,
          where: 'id = ?',
          whereArgs: [draftId],
        );
      }

      // Save draft version history
      await db.insert('draft_versions', {
        'draft_id': draftId,
        'version': draft.version,
        'subject': draft.subject,
        'body': draft.body,
        'is_html': draft.isHtml ? 1 : 0,
        'to_recipients': draft.toRecipients.join(','),
        'cc_recipients': draft.ccRecipients.join(','),
        'bcc_recipients': draft.bccRecipients.join(','),
        'attachment_paths': draft.attachmentPaths.join(','),
        'created_at': now,
      });
    });

    return draftId;
  }


  /// Deletes multiple drafts (and their version‐history) in one shot.
  Future<void> batchDeleteDrafts(List<int> draftIds) async {
    if (draftIds.isEmpty) return;

    await _withWriteDb((txn) async {
      final placeholders = List.filled(draftIds.length, '?').join(',');
      // first remove any history entries
      await txn.delete(
        'draft_versions',
        where: 'draft_id IN ($placeholders)',
        whereArgs: draftIds,
      );
      // then remove the drafts themselves
      await txn.delete(
        'drafts',
        where: 'id IN ($placeholders)',
        whereArgs: draftIds,
      );
    });
  }



  /// Search drafts by matching subject, body or recipients (to/cc/bcc).
  Future<List<DraftModel>> searchDrafts(String query) async {
    final likeQuery = '%${query.toLowerCase()}%';
    return await _withReadDb((db) async {
      final maps = await db.query(
        'drafts',
        where: '''
        LOWER(subject)   LIKE ? OR
        LOWER(body)      LIKE ? OR
        LOWER(to_recipients)   LIKE ? OR
        LOWER(cc_recipients)   LIKE ? OR
        LOWER(bcc_recipients)  LIKE ?
      ''',
        whereArgs: [likeQuery, likeQuery, likeQuery, likeQuery, likeQuery],
        orderBy: 'updated_at DESC',
      );

      return maps.map((map) {
        // parse tags into a List<String>
        final rawTags = map['tags'] as String?;
        final tags = rawTags != null
            ? rawTags.split(',').where((s) => s.isNotEmpty).toList()
            : <String>[];
        return DraftModel(
          id: map['id'] as int,
          messageId: map['message_id'] as String?,
          subject: map['subject'] as String,
          body: map['body'] as String,
          isHtml: map['is_html'] == 1,
          to: (map['to_recipients'] as String).split(',').where((s) => s.isNotEmpty).toList(),
          cc: (map['cc_recipients'] as String).split(',').where((s) => s.isNotEmpty).toList(),
          bcc: (map['bcc_recipients'] as String).split(',').where((s) => s.isNotEmpty).toList(),
          attachmentPaths: (map['attachment_paths'] as String).split(',').where((s) => s.isNotEmpty).toList(),
          createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
          isScheduled: map['is_scheduled'] == 1,
          scheduledFor: map['scheduled_for'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['scheduled_for'] as int)
              : null,
          version: map['version'] as int,
          category: map['category'] as String,
          priority: map['priority'] as int,
          isSynced: map['is_synced'] == 1,
          serverUid: map['server_uid'] as int?,
          isDirty: map['is_dirty'] == 1,
          tags: tags,
          lastError: map['last_error'] as String?,
        );
      }).toList();
    });
  }
  Future<List<DraftModel>> getDrafts({String? category}) async {
    return await _withReadDb((db) async {
      String? whereClause;
      List<dynamic>? whereArgs;

      if (category != null) {
        whereClause = 'category = ?';
        whereArgs = [category];
      }

      final maps = await db.query(
        'drafts',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'updated_at DESC',
      );

      return maps.map((map) {
        // split tags or give an empty list if null
        final rawTags = map['tags'] as String?;
        final tags = rawTags != null
            ? rawTags.split(',').where((s) => s.isNotEmpty).toList()
            : <String>[];

        return DraftModel(
          id: map['id'] as int,
          messageId: map['message_id'] as String?,
          subject: map['subject'] as String,
          body: map['body'] as String,
          isHtml: map['is_html'] == 1,
          to: (map['to_recipients'] as String)
              .split(',')
              .where((s) => s.isNotEmpty)
              .toList(),
          cc: (map['cc_recipients'] as String)
              .split(',')
              .where((s) => s.isNotEmpty)
              .toList(),
          bcc: (map['bcc_recipients'] as String)
              .split(',')
              .where((s) => s.isNotEmpty)
              .toList(),
          attachmentPaths: (map['attachment_paths'] as String)
              .split(',')
              .where((s) => s.isNotEmpty)
              .toList(),
          createdAt:
          DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
          updatedAt:
          DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
          isScheduled: map['is_scheduled'] == 1,
          scheduledFor: map['scheduled_for'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
              map['scheduled_for'] as int)
              : null,
          version: map['version'] as int,
          category: map['category'] as String,
          priority: map['priority'] as int,
          isSynced: map['is_synced'] == 1,
          serverUid: map['server_uid'] as int?,
          isDirty: map['is_dirty'] == 1,
          tags: tags,      // <-- now always a List<String>
          lastError: map['last_error'] as String?,
        );
      }).toList();
    });
  }

  Future<DraftModel?> getDraftById(int id) async {
    return await _withReadDb((db) async {
      final maps = await db.query(
        'drafts',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isEmpty) return null;
      final map = maps.first;

      // Always produce a non-null List<String>
      final rawTags = map['tags'] as String?;
      final tags = rawTags != null
          ? rawTags.split(',').where((s) => s.isNotEmpty).toList()
          : <String>[];

      return DraftModel(
        id: map['id'] as int,
        messageId: map['message_id'] as String?,
        subject: map['subject'] as String,
        body: map['body'] as String,
        isHtml: map['is_html'] == 1,
        to: (map['to_recipients'] as String)
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
        cc: (map['cc_recipients'] as String)
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
        bcc: (map['bcc_recipients'] as String)
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
        attachmentPaths: (map['attachment_paths'] as String)
            .split(',')
            .where((s) => s.isNotEmpty)
            .toList(),
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
        isScheduled: map['is_scheduled'] == 1,
        scheduledFor: map['scheduled_for'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['scheduled_for'] as int)
            : null,
        version: map['version'] as int,
        category: map['category'] as String,
        priority: map['priority'] as int,
        isSynced: map['is_synced'] == 1,
        serverUid: map['server_uid'] as int?,
        isDirty: map['is_dirty'] == 1,
        tags: tags,          // always non-null List<String>
        lastError: map['last_error'] as String?,
      );
    });
  }
  Future<void> deleteDraft(int id) async {
    await _withWriteDb((txn) async {
      await txn.delete(
        'drafts',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<List<Map<String, dynamic>>> getDraftVersions(int draftId) async {
    return await _withReadDb((db) async {
      return await db.query(
        'draft_versions',
        where: 'draft_id = ?',
        whereArgs: [draftId],
        orderBy: 'version DESC',
      );
    });
  }

  // Contact suggestions
  Future<void> updateContactFromAddress(MailAddress address) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _withWriteDb((txn) async {
      // Check if contact exists
      final maps = await txn.query(
        'contacts',
        where: 'email = ?',
        whereArgs: [address.email],
      );

      if (maps.isEmpty) {
        // Insert new contact
        await txn.insert('contacts', {
          'name': address.personalName,
          'email': address.email,
          'frequency': 1,
          'last_used': now,
        });
      } else {
        // Update existing contact
        final frequency = maps.first['frequency'] as int;
        await txn.update(
          'contacts',
          {
            'frequency': frequency + 1,
            'last_used': now,
            'name': address.personalName ?? maps.first['name'],
          },
          where: 'email = ?',
          whereArgs: [address.email],
        );
      }
    });
  }

  // Update contact suggestions from message
  void _updateContactsFromMessage(MimeMessage message) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final addresses = <MailAddress>[];

    // Collect all addresses
    if (message.from != null) addresses.addAll(message.from!);
    if (message.to != null) addresses.addAll(message.to!);
    if (message.cc != null) addresses.addAll(message.cc!);
    if (message.replyTo != null) addresses.addAll(message.replyTo!);

    // Process each address
    for (final address in addresses) {
      if (address.email.isEmpty) continue;

      await _withWriteDb((txn) async {
        // Check if contact exists
        final maps = await txn.query(
          'contacts',
          where: 'email = ?',
          whereArgs: [address.email],
        );

        if (maps.isEmpty) {
          // Insert new contact
          await txn.insert('contacts', {
            'name': address.personalName,
            'email': address.email,
            'frequency': 1,
            'last_used': now,
          });
        } else {
          // Update existing contact
          final frequency = maps.first['frequency'] as int;
          await txn.update(
            'contacts',
            {
              'frequency': frequency + 1,
              'last_used': now,
              'name': address.personalName ?? maps.first['name'],
            },
            where: 'email = ?',
            whereArgs: [address.email],
          );
        }
      });
    }
  }

  Future<List<Map<String, dynamic>>> getContactSuggestions(String query, {int limit = 10}) async {
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (query.isNotEmpty) {
      whereClause = 'email LIKE ? OR name LIKE ?';
      whereArgs = ['%$query%', '%$query%'];
    }

    return await _withReadDb((db) async {
      return await db.query(
        'contacts',
        where: whereClause.isNotEmpty ? whereClause : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'frequency DESC, last_used DESC',
        limit: limit,
      );
    });
  }

  // Cleanup and disposal
  Future<void> dispose() async {
    _cacheInvalidationTimer?.cancel();
    _messageUpdateController.close();
    _writeQueue.close();
  }
}

// Helper class for write operations
class _WriteOperation {
  final Future<void> Function(Transaction txn) execute;
  final Completer<bool> completer;

  _WriteOperation(this.execute, this.completer);
}

// Helper class for message updates
class _MessageUpdate {
  final String accountId;
  final String mailboxPath;
  final List<MimeMessage> messages;
  final MessageUpdateType type;

  _MessageUpdate({
    required this.accountId,
    required this.mailboxPath,
    required this.messages,
    required this.type,
  });
}

// Update type for message notifications
enum MessageUpdateType {
  update,
  delete,
  flagUpdate,
  clear,
}

// LRU Cache implementation
class _LRUCache<K, V> {
  final int capacity;
  final LinkedHashMap<K, _CacheEntry<V>> _cache = LinkedHashMap<K, _CacheEntry<V>>();

  _LRUCache(this.capacity);

  V? get(K key) {
    final entry = _cache[key];
    if (entry == null) return null;

    // Move to front (most recently used)
    _cache.remove(key);
    _cache[key] = entry;

    return entry.value;
  }

  void put(K key, V value) {
    // Remove if already exists
    _cache.remove(key);

    // Check if cache is full
    if (_cache.length >= capacity) {
      // Remove least recently used item (first item)
      _cache.remove(_cache.keys.first);
    }

    // Add new item
    _cache[key] = _CacheEntry<V>(value, DateTime.now().millisecondsSinceEpoch);
  }

  void remove(K key) {
    _cache.remove(key);
  }

  void clear() {
    _cache.clear();
  }

  void removeOlderThan(int timestamp) {
    final keysToRemove = <K>[];
    for (final entry in _cache.entries) {
      if (entry.value.timestamp < timestamp) {
        keysToRemove.add(entry.key);
      }
    }
    for (final key in keysToRemove) {
      _cache.remove(key);
    }
  }
}



// Cache entry with timestamp
class _CacheEntry<V> {
  final V value;
  final int timestamp;

  _CacheEntry(this.value, this.timestamp);
}
