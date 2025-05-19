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
import 'package:wahda_bank/views/compose/models/draft_model.dart';

/// SQLite-based storage for MIME messages with ultra-optimized performance
///
/// This class provides optimized storage and retrieval of email messages
/// using SQLite with advanced lock avoidance strategies.
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

  // Enhanced LRU cache with size limit
  final _messageCache = _LRUCache<String, MimeMessage>(500);

  // Stream controller for message updates
  final _messageUpdateController = BehaviorSubject<_MessageUpdate>();
  Stream<_MessageUpdate> get messageUpdateStream => _messageUpdateController.stream;

  // Flag to track if a transaction is in progress
  bool _isInTransaction = false;

  factory SqliteMimeStorage() => instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mime_messages.db');

    // Initialize write queue processor if not already done
    if (!_isWriteQueueInitialized) {
      _initWriteQueue();
    }

    return _database!;
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
    }
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

  // Message operations with optimized batching
  Future<String> insertMessage(MimeMessage message, String accountId, String mailboxPath) async {
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

    // Insert or replace the message with transaction
    await _withWriteDb((txn) async {
      await txn.insert(
        'messages',
        messageMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    // Update cache
    _messageCache.put(id, message);

    // Notify listeners about the update
    _notifyMessageUpdate(accountId, mailboxPath, [message]);

    // Update contact suggestions from recipients in background
    _updateContactsFromMessage(message);

    return id;
  }

  // Optimized batch saving of messages
  Future<void> saveMessageEnvelopes(List<MimeMessage> messages, [String? accountId, String? mailboxPath]) async {
    if (messages.isEmpty) return;

    // Skip if no account or mailbox info
    if (accountId == null || mailboxPath == null) {
      debugPrint('Cannot save messages: missing mailbox path');
      return;
    }

    // Pre-build the rows OUTSIDE the transaction
    final rows = <Map<String, dynamic>>[];
    final updatedMessages = <MimeMessage>[];

    for (final msg in messages) {
      final uid = msg.uid;
      if (uid == null) continue;

      // Get the raw source of the message for storage
      String mimeSource = '';
      try {
        if (msg.mimeData != null) {
          mimeSource = msg.toString();
        }
      } catch (e) {
        print('Error getting MIME source: $e');
        continue;
      }

      final id = '${accountId}_${mailboxPath}_${uid}';

      rows.add({
        'id': id,
        'account_id': accountId,
        'mailbox_path': mailboxPath,
        'sequence_id': msg.sequenceId ?? 0,
        'uid': uid,
        'subject': msg.decodeSubject() ?? '',
        'from_email': msg.fromEmail ?? '',
        'to_email': msg.to != null ? msg.to!.map((e) => e.email).join(', ') : '',
        'cc_email': msg.cc != null ? msg.cc!.map((e) => e.email).join(', ') : '',
        'bcc_email': msg.bcc != null ? msg.bcc!.map((e) => e.email).join(', ') : '',
        'date': msg.decodeDate()?.toIso8601String() ?? DateTime.now().toIso8601String(),
        'size': msg.size ?? 0,
        'is_seen': msg.isSeen ? 1 : 0,
        'is_flagged': msg.isFlagged ? 1 : 0,
        'is_answered': msg.isAnswered ? 1 : 0,
        'is_forwarded': msg.isForwarded ? 1 : 0,
        'has_attachments': msg.hasAttachments() ? 1 : 0,
        'mime_source': mimeSource,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Update cache
      _messageCache.put(id, msg);
      updatedMessages.add(msg);
    }

    // Process in batches of 20 for very large message lists (smaller batches to reduce lock time)
    const int maxBatchSize = 20;
    for (int i = 0; i < rows.length; i += maxBatchSize) {
      final int end = (i + maxBatchSize < rows.length) ? i + maxBatchSize : rows.length;
      final batch = rows.sublist(i, end);

      // One fast commit with transaction
      await _withWriteDb((txn) async {
        final batchOp = txn.batch();
        for (final row in batch) {
          batchOp.insert(
            'messages',
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batchOp.commit(noResult: true);
      });

      // Yield to UI thread between batches
      if (end < rows.length) {
        await Future.delayed(Duration.zero);
      }
    }

    // Notify listeners about the updates
    if (updatedMessages.isNotEmpty) {
      _notifyMessageUpdate(accountId, mailboxPath, updatedMessages);
    }

    // Update contacts in background
    _updateContactsFromMessagesInBackground(messages);
  }

  // Delete a message with transaction
  Future<void> deleteMessage(MimeMessage message, [String? accountId, String? mailboxPath]) async {
    final uid = message.uid;
    if (uid == null) return;

    // Try to extract from message if not provided
    if (accountId == null || mailboxPath == null) {
      debugPrint('Cannot delete message: missing mailbox path');
      return;
    }

    final id = '${accountId}_${mailboxPath}_${uid}';

    await _withWriteDb((txn) async {
      await txn.delete(
        'messages',
        where: 'id = ?',
        whereArgs: [id],
      );
    });

    // Remove from cache
    _messageCache.remove(id);

    // Notify listeners about the deletion
    _notifyMessageDelete(accountId, mailboxPath, [message]);
  }

  // NEW METHOD: Update message flags in database
  Future<void> updateMessageFlags(MimeMessage message, String accountId, String mailboxPath) async {
    final uid = message.uid;
    if (uid == null) return;

    final id = '${accountId}_${mailboxPath}_${uid}';

    // Update flags in database
    await _withWriteDb((txn) async {
      await txn.update(
        'messages',
        {
          'is_seen': message.isSeen ? 1 : 0,
          'is_flagged': message.isFlagged ? 1 : 0,
          'is_answered': message.isAnswered ? 1 : 0,
          'is_forwarded': message.isForwarded ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });

    // Update cache
    _messageCache.put(id, message);

    // Notify listeners about the flag update
    _notifyMessageFlagUpdate(accountId, mailboxPath, message);
  }

  // Batch update message flags for better performance
  Future<void> batchUpdateMessageFlags(List<MimeMessage> messages, String accountId, String mailboxPath) async {
    if (messages.isEmpty) return;

    await _withWriteDb((txn) async {
      final batch = txn.batch();

      for (final message in messages) {
        final uid = message.uid;
        if (uid == null) continue;

        final id = '${accountId}_${mailboxPath}_${uid}';

        batch.update(
          'messages',
          {
            'is_seen': message.isSeen ? 1 : 0,
            'is_flagged': message.isFlagged ? 1 : 0,
            'is_answered': message.isAnswered ? 1 : 0,
            'is_forwarded': message.isForwarded ? 1 : 0,
          },
          where: 'id = ?',
          whereArgs: [id],
        );

        // Update cache
        _messageCache.put(id, message);
      }

      await batch.commit(noResult: true);
    });

    // Notify listeners about the batch flag update
    _notifyMessageUpdate(accountId, mailboxPath, messages);
  }

  // NEW METHOD: Delete all messages for a specific mailbox
  Future<void> deleteMessagesForMailbox(String accountId, String mailboxPath) async {
    // Delete from database
    await _withWriteDb((txn) async {
      await txn.delete(
        'messages',
        where: 'account_id = ? AND mailbox_path = ?',
        whereArgs: [accountId, mailboxPath],
      );
    });

    // Clear cache for this mailbox
    final prefix = '${accountId}_${mailboxPath}_';
    _messageCache.removeWhere((key) => key.startsWith(prefix));

    // Notify listeners about the mailbox clear
    _notifyMailboxClear(accountId, mailboxPath);
  }

  // Fetch messages for a mailbox with optimized query
  Future<List<MimeMessage>> fetchMessagesForMailbox(String accountId, String mailboxPath, {
    int limit = 50,
    int offset = 0,
    String orderBy = 'date DESC',
    bool? onlySeen,
    bool? onlyFlagged,
  }) async {
    // Build where clause
    String whereClause = 'account_id = ? AND mailbox_path = ?';
    List<dynamic> whereArgs = [accountId, mailboxPath];

    if (onlySeen != null) {
      whereClause += ' AND is_seen = ?';
      whereArgs.add(onlySeen ? 1 : 0);
    }

    if (onlyFlagged != null) {
      whereClause += ' AND is_flagged = ?';
      whereArgs.add(onlyFlagged ? 1 : 0);
    }

    final maps = await _withReadDb((db) async {
      return await db.query(
        'messages',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
    });

    final messages = <MimeMessage>[];

    for (final map in maps) {
      final message = _mapToMimeMessage(map);
      if (message != null) {
        messages.add(message);

        // Update cache
        final id = map['id'] as String;
        _messageCache.put(id, message);
      }
    }

    return messages;
  }

  // Convert database map to MimeMessage
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

        return message;
      } else {
        // Create a message from the envelope data
        final message = MimeMessage();

        // Set basic properties
        message.uid = map['uid'] as int;
        message.sequenceId = map['sequence_id'] as int;

        // Set flags
        message.isSeen = map['is_seen'] == 1;
        message.isFlagged = map['is_flagged'] == 1;
        message.isAnswered = map['is_answered'] == 1;
        message.isForwarded = map['is_forwarded'] == 1;

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
            print('Error parsing date: $e');
          }
        }

        // Set from
        final fromEmail = map['from_email'] as String?;
        if (fromEmail != null && fromEmail.isNotEmpty) {
          message.from = [MailAddress(null, fromEmail)];
        }

        // Set to
        final toEmail = map['to_email'] as String?;
        if (toEmail != null && toEmail.isNotEmpty) {
          message.to = toEmail.split(', ')
              .map((email) => MailAddress(null, email.trim()))
              .toList();
        }

        // Set cc
        final ccEmail = map['cc_email'] as String?;
        if (ccEmail != null && ccEmail.isNotEmpty) {
          message.cc = ccEmail.split(', ')
              .map((email) => MailAddress(null, email.trim()))
              .toList();
        }

        // Set bcc
        final bccEmail = map['bcc_email'] as String?;
        if (bccEmail != null && bccEmail.isNotEmpty) {
          message.bcc = bccEmail.split(', ')
              .map((email) => MailAddress(null, email.trim()))
              .toList();
        }

        return message;
      }
    } catch (e) {
      print('Error converting map to MimeMessage: $e');
      return null;
    }
  }

  // Notification methods for reactive updates
  void _notifyMessageUpdate(String accountId, String mailboxPath, List<MimeMessage> messages) {
    if (!_messageUpdateController.isClosed && messages.isNotEmpty) {
      _messageUpdateController.add(_MessageUpdate(
        type: MessageUpdateType.update,
        accountId: accountId,
        mailboxPath: mailboxPath,
        messages: messages,
      ));
    }
  }

  void _notifyMessageDelete(String accountId, String mailboxPath, List<MimeMessage> messages) {
    if (!_messageUpdateController.isClosed && messages.isNotEmpty) {
      _messageUpdateController.add(_MessageUpdate(
        type: MessageUpdateType.delete,
        accountId: accountId,
        mailboxPath: mailboxPath,
        messages: messages,
      ));
    }
  }

  void _notifyMessageFlagUpdate(String accountId, String mailboxPath, MimeMessage message) {
    if (!_messageUpdateController.isClosed) {
      _messageUpdateController.add(_MessageUpdate(
        type: MessageUpdateType.flagUpdate,
        accountId: accountId,
        mailboxPath: mailboxPath,
        messages: [message],
      ));
    }
  }

  void _notifyMailboxClear(String accountId, String mailboxPath) {
    if (!_messageUpdateController.isClosed) {
      _messageUpdateController.add(_MessageUpdate(
        type: MessageUpdateType.clear,
        accountId: accountId,
        mailboxPath: mailboxPath,
        messages: [],
      ));
    }
  }

  // Draft operations with optimized batching
  Future<DraftModel> saveDraft(DraftModel draft) async {
    final now = DateTime.now();

    // Create a copy with updated timestamp and clean state
    final updatedDraft = draft.copyWith(
      updatedAt: now,
      isDirty: false,
    );

    final draftMap = updatedDraft.toMap();

    // Initialize id with a default value
    int id = draft.id ?? -1;

    await _withWriteDb((txn) async {
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
          await _saveDraftVersionWithTxn(txn, draft);
        }
      } else {
        // Insert new draft
        id = await txn.insert('drafts', draftMap);
      }
    });

    // Return updated draft with ID
    return updatedDraft.copyWith(id: id);
  }

  // Save draft version for history tracking - transaction version
  Future<void> _saveDraftVersionWithTxn(Transaction txn, DraftModel draft) async {
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

  // Original method for backward compatibility
  Future<void> _saveDraftVersion(Transaction txn, DraftModel draft) async {
    await _saveDraftVersionWithTxn(txn, draft);
  }

  Future<DraftModel?> getDraft(int id) async {
    final maps = await _withReadDb((db) async {
      return await db.query(
        'drafts',
        where: 'id = ?',
        whereArgs: [id],
      );
    });

    if (maps.isEmpty) {
      return null;
    }

    return DraftModel.fromMap(maps.first);
  }

  Future<DraftModel?> getDraftByMessageId(String messageId) async {
    final maps = await _withReadDb((db) async {
      return await db.query(
        'drafts',
        where: 'message_id = ?',
        whereArgs: [messageId],
      );
    });

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

    final maps = await _withReadDb((db) async {
      return await db.query(
        'drafts',
        where: whereClause.isNotEmpty ? whereClause : null,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'updated_at DESC',
        limit: limit,
        offset: offset,
      );
    });

    return maps.map((map) => DraftModel.fromMap(map)).toList();
  }

  Future<List<DraftModel>> getScheduledDrafts() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    final maps = await _withReadDb((db) async {
      return await db.query(
        'drafts',
        where: 'is_scheduled = 1 AND scheduled_for <= ?',
        whereArgs: [now],
        orderBy: 'scheduled_for ASC',
      );
    });

    return maps.map((map) => DraftModel.fromMap(map)).toList();
  }

  Future<List<DraftModel>> getDraftsByCategory(String category) async {
    final maps = await _withReadDb((db) async {
      return await db.query(
        'drafts',
        where: 'category = ?',
        whereArgs: [category],
        orderBy: 'updated_at DESC',
      );
    });

    return maps.map((map) => DraftModel.fromMap(map)).toList();
  }

  Future<List<DraftModel>> searchDrafts(String query) async {
    final maps = await _withReadDb((db) async {
      return await db.query(
        'drafts',
        where: 'subject LIKE ? OR body LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'updated_at DESC',
      );
    });

    return maps.map((map) => DraftModel.fromMap(map)).toList();
  }

  Future<List<DraftModel>> getDirtyDrafts() async {
    final maps = await _withReadDb((db) async {
      return await db.query(
        'drafts',
        where: 'is_dirty = 1',
        orderBy: 'updated_at DESC',
      );
    });

    return maps.map((map) => DraftModel.fromMap(map)).toList();
  }

  Future<int> deleteDraft(int id) async {
    int result = 0;

    await _withWriteDb((txn) async {
      // Delete draft versions first
      await txn.delete(
        'draft_versions',
        where: 'draft_id = ?',
        whereArgs: [id],
      );

      // Then delete the draft
      result = await txn.delete(
        'drafts',
        where: 'id = ?',
        whereArgs: [id],
      );
    });

    return result;
  }

  Future<int> deleteDraftByMessageId(String messageId) async {
    // First get the draft to find its ID
    final draft = await getDraftByMessageId(messageId);
    if (draft == null || draft.id == null) {
      return 0;
    }

    return await deleteDraft(draft.id!);
  }

  Future<List<Map<String, dynamic>>> getDraftVersionHistory(int draftId) async {
    return await _withReadDb((db) async {
      return await db.query(
        'draft_versions',
        where: 'draft_id = ?',
        whereArgs: [draftId],
        orderBy: 'version DESC',
      );
    });
  }

  Future<DraftModel?> restoreDraftVersion(int draftId, int version) async {
    final versionMaps = await _withReadDb((db) async {
      return await db.query(
        'draft_versions',
        where: 'draft_id = ? AND version = ?',
        whereArgs: [draftId, version],
      );
    });

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
    int result = 0;

    await _withWriteDb((txn) async {
      result = await txn.update(
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
    });

    return result;
  }

  Future<int> markDraftSyncError(int id, String error) async {
    int result = 0;

    await _withWriteDb((txn) async {
      result = await txn.update(
        'drafts',
        {
          'is_synced': 0,
          'last_error': error,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });

    return result;
  }

  Future<int> updateDraftCategory(int id, String category) async {
    int result = 0;

    await _withWriteDb((txn) async {
      result = await txn.update(
        'drafts',
        {'category': category},
        where: 'id = ?',
        whereArgs: [id],
      );
    });

    return result;
  }

  Future<int> updateDraftTags(int id, List<String> tags) async {
    int result = 0;

    await _withWriteDb((txn) async {
      result = await txn.update(
        'drafts',
        {'tags': tags.join('||')},
        where: 'id = ?',
        whereArgs: [id],
      );
    });

    return result;
  }

  Future<int> batchDeleteDrafts(List<int> ids) async {
    int result = 0;

    await _withWriteDb((txn) async {
      // Delete draft versions first
      await txn.delete(
        'draft_versions',
        where: 'draft_id IN (${ids.map((_) => '?').join(', ')})',
        whereArgs: ids,
      );

      // Then delete the drafts
      result = await txn.delete(
        'drafts',
        where: 'id IN (${ids.map((_) => '?').join(', ')})',
        whereArgs: ids,
      );
    });

    return result;
  }

  Future<int> batchUpdateDraftCategory(List<int> ids, String category) async {
    int result = 0;

    await _withWriteDb((txn) async {
      result = await txn.update(
        'drafts',
        {'category': category},
        where: 'id IN (${ids.map((_) => '?').join(', ')})',
        whereArgs: ids,
      );
    });

    return result;
  }

  // Contact suggestion operations with background processing
  Future<void> _updateContactsFromMessage(MimeMessage message) async {
    // Process in background to avoid blocking UI
    Future.microtask(() async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Process all recipients
      final allRecipients = [
        ...message.to ?? [],
        ...message.cc ?? [],
        ...message.bcc ?? [],
        ...message.from ?? [],
      ];

      if (allRecipients.isEmpty) return;

      await _withWriteDb((txn) async {
        final batch = txn.batch();

        for (final recipient in allRecipients) {
          if (recipient.email.isNotEmpty) {
            try {
              // Use raw SQL for upsert-style operation
              batch.rawInsert(
                  'INSERT INTO contacts (name, email, frequency, last_used) VALUES (?, ?, 1, ?) '
                      'ON CONFLICT(email) DO UPDATE SET '
                      'frequency = frequency + 1, '
                      'last_used = ?, '
                      'name = CASE WHEN name IS NULL OR name = "" THEN ? ELSE name END',
                  [
                    recipient.personalName ?? '',
                    recipient.email,
                    now,
                    now,
                    recipient.personalName ?? ''
                  ]
              );
            } catch (e) {
              print('Error preparing contact batch: $e');
            }
          }
        }

        await batch.commit(noResult: true);
      });
    });
  }

  // Process multiple messages for contacts in background
  Future<void> _updateContactsFromMessagesInBackground(List<MimeMessage> messages) async {
    if (messages.isEmpty) return;

    // Process in background to avoid blocking UI
    Future.microtask(() async {
      final now = DateTime.now().millisecondsSinceEpoch;

      // Extract all unique recipients
      final Set<MailAddress> allRecipients = {};
      for (final message in messages) {
        if (message.to != null) allRecipients.addAll(message.to!);
        if (message.cc != null) allRecipients.addAll(message.cc!);
        if (message.bcc != null) allRecipients.addAll(message.bcc!);
        if (message.from != null) allRecipients.addAll(message.from!);
      }

      if (allRecipients.isEmpty) return;

      await _withWriteDb((txn) async {
        final batch = txn.batch();

        for (final recipient in allRecipients) {
          if (recipient.email.isNotEmpty) {
            try {
              // Use raw SQL for upsert-style operation
              batch.rawInsert(
                  'INSERT INTO contacts (name, email, frequency, last_used) VALUES (?, ?, 1, ?) '
                      'ON CONFLICT(email) DO UPDATE SET '
                      'frequency = frequency + 1, '
                      'last_used = ?, '
                      'name = CASE WHEN name IS NULL OR name = "" THEN ? ELSE name END',
                  [
                    recipient.personalName ?? '',
                    recipient.email,
                    now,
                    now,
                    recipient.personalName ?? ''
                  ]
              );
            } catch (e) {
              print('Error preparing contact batch: $e');
            }
          }
        }

        await batch.commit(noResult: true);
      });
    });
  }

  // Dispose resources
  void dispose() {
    _writeQueue.close();
    _messageUpdateController.close();
  }
}

// Helper class for write operations
class _WriteOperation {
  final Future<void> Function(Transaction txn) execute;
  final Completer<bool> completer;

  _WriteOperation(this.execute, this.completer);
}

// Enhanced LRU cache implementation
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

  void removeWhere(bool Function(K key) test) {
    _cache.removeWhere((key, _) => test(key));
  }

  void clear() {
    _cache.clear();
  }

  bool containsKey(K key) {
    return _cache.containsKey(key);
  }

  int get length => _cache.length;
}

// Message update types
enum MessageUpdateType {
  update,
  delete,
  flagUpdate,
  clear,
}

// Message update class for stream
class _MessageUpdate {
  final MessageUpdateType type;
  final String accountId;
  final String mailboxPath;
  final List<MimeMessage> messages;

  _MessageUpdate({
    required this.type,
    required this.accountId,
    required this.mailboxPath,
    required this.messages,
  });
}
