import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:wahda_bank/models/sqlite_database_helper.dart';
import 'package:wahda_bank/services/feature_flags.dart';

class CachedAttachment {
  final String? contentId;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final bool isInline;
  final String filePath;

  const CachedAttachment({
    required this.contentId,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.isInline,
    required this.filePath,
  });

  Map<String, Object?> toMap(
    String accountEmail,
    String mailboxPath,
    int uidValidity,
    int uid,
  ) => {
    'content_id': contentId,
    'file_name': fileName,
    'mime_type': mimeType,
    'size_bytes': sizeBytes,
    'is_inline': isInline ? 1 : 0,
    'file_path': filePath,
    'account_email': accountEmail,
    'mailbox_path': mailboxPath,
    'uid_validity': uidValidity,
    'uid': uid,
  };

  static CachedAttachment fromMap(Map<String, Object?> row) => CachedAttachment(
    contentId: row['content_id'] as String?,
    fileName: (row['file_name'] ?? '') as String,
    mimeType: (row['mime_type'] ?? 'application/octet-stream') as String,
    sizeBytes:
        (row['size_bytes'] is int)
            ? row['size_bytes'] as int
            : int.tryParse(row['size_bytes']?.toString() ?? '0') ?? 0,
    isInline:
        (row['is_inline'] is int) ? (row['is_inline'] as int) == 1 : false,
    filePath: (row['file_path'] ?? '') as String,
  );
}

class CachedMessageContent {
  final String? plainText; // decompressed
  final String? htmlSanitizedBlocked; // decompressed
  final String? htmlFilePath; // on-disk materialized HTML
  final int sanitizedVersion;
  final List<CachedAttachment> attachments;

  const CachedMessageContent({
    required this.plainText,
    required this.htmlSanitizedBlocked,
    required this.htmlFilePath,
    required this.sanitizedVersion,
    required this.attachments,
  });
}

class MessageContentStore {
  MessageContentStore._();
  static final instance = MessageContentStore._();

  final _gz = GZipCodec();

  Future<Database> get _db async => SQLiteDatabaseHelper.instance.database;

  Future<void> upsertContent({
    required String accountEmail,
    required String mailboxPath,
    required int uidValidity,
    required int uid,
    String? plainText,
    String? htmlSanitizedBlocked,
    String? htmlFilePath,
    required int sanitizedVersion,
    List<CachedAttachment> attachments = const [],
    bool forceMaterialize = false,
  }) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;

    final plainBlob =
        plainText == null ? null : _gz.encode(utf8.encode(plainText));

    // Decide whether to store HTML inline or as file based on size and feature flags
    String? actualHtmlFilePath = htmlFilePath;
    List<int>? htmlBlob;

    final ff = FeatureFlags.instance;
    final matEnabled = ff.htmlMaterializationEnabled;
    final threshold = ff.htmlMaterializationThresholdBytes;

    if (htmlSanitizedBlocked != null && htmlFilePath == null) {
      final htmlBytes = utf8.encode(htmlSanitizedBlocked);
      final shouldMaterialize =
          matEnabled && (forceMaterialize || htmlBytes.length > threshold);
      if (shouldMaterialize) {
        // Materialize to file for performance, but ALSO keep a compressed inline fallback for resilience
        actualHtmlFilePath = await saveOfflineHtmlDocument(
          accountEmail: accountEmail,
          mailboxPath: mailboxPath,
          uidValidity: uidValidity,
          uid: uid,
          sanitizedInnerHtml: htmlSanitizedBlocked,
          blockRemote: true, // Default to blocked for cached content
        );
        htmlBlob = _gz.encode(
          htmlBytes,
        ); // Keep fallback inline HTML in DB for when the file is missing
      } else {
        // Store inline as blob
        htmlBlob = _gz.encode(htmlBytes);
      }
    } else if (htmlSanitizedBlocked != null) {
      // Both provided: keep inline copy as fallback regardless of materialization
      htmlBlob = _gz.encode(utf8.encode(htmlSanitizedBlocked));
    }

    await db.transaction((txn) async {
      await txn.insert(
        SQLiteDatabaseHelper.tableMessageContent,
        {
          'account_email': accountEmail,
          'mailbox_path': mailboxPath,
          'uid_validity': uidValidity,
          'uid': uid,
          'plain_text': plainBlob,
          'html_sanitized_blocked': htmlBlob,
          'html_file_path': actualHtmlFilePath,
          'sanitized_version': sanitizedVersion,
          'has_attachments': attachments.isNotEmpty ? 1 : 0,
          'stored_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Clear existing attachments for this message and re-insert
      await txn.delete(
        SQLiteDatabaseHelper.tableMessageAttachments,
        where:
            'account_email=? AND mailbox_path=? AND uid_validity=? AND uid=?',
        whereArgs: [accountEmail, mailboxPath, uidValidity, uid],
      );
      if (attachments.isNotEmpty) {
        final batch = txn.batch();
        for (final a in attachments) {
          batch.insert(
            SQLiteDatabaseHelper.tableMessageAttachments,
            a.toMap(accountEmail, mailboxPath, uidValidity, uid),
          );
        }
        await batch.commit(noResult: true);
      }
    });
  }

  Future<CachedMessageContent?> getContent({
    required String accountEmail,
    required String mailboxPath,
    required int uidValidity,
    required int uid,
  }) async {
    final db = await _db;
    final rows = await db.query(
      SQLiteDatabaseHelper.tableMessageContent,
      where: 'account_email=? AND mailbox_path=? AND uid_validity=? AND uid=?',
      whereArgs: [accountEmail, mailboxPath, uidValidity, uid],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    String? plain;
    String? html;
    String? htmlPath;
    try {
      if (row['plain_text'] != null) {
        plain = utf8.decode(_gz.decode(row['plain_text'] as List<int>));
      }
    } catch (_) {}
    try {
      if (row['html_sanitized_blocked'] != null) {
        html = utf8.decode(
          _gz.decode(row['html_sanitized_blocked'] as List<int>),
        );
      }
      if (row['html_file_path'] != null) {
        htmlPath = row['html_file_path'] as String?;
      }
    } catch (_) {}
    final version =
        (row['sanitized_version'] is int)
            ? row['sanitized_version'] as int
            : int.tryParse(row['sanitized_version']?.toString() ?? '1') ?? 1;

    final attRows = await db.query(
      SQLiteDatabaseHelper.tableMessageAttachments,
      where: 'account_email=? AND mailbox_path=? AND uid_validity=? AND uid=?',
      whereArgs: [accountEmail, mailboxPath, uidValidity, uid],
      orderBy: 'id ASC',
    );
    final atts = attRows.map(CachedAttachment.fromMap).toList();

    if (kDebugMode) {
      int htmlLen = html?.length ?? 0;
      bool exists = false;
      int size = -1;
      try {
        if (htmlPath != null && htmlPath.isNotEmpty) {
          final f = File(htmlPath);
          exists = f.existsSync();
          if (exists) size = f.statSync().size;
        }
      } catch (_) {}
      // ignore: avoid_print
      print(
        'STORE:getContent uid=$uid box=$mailboxPath v=$version htmlLen=$htmlLen htmlPath=$htmlPath exists=$exists size=$size',
      );
    }

    return CachedMessageContent(
      plainText: plain,
      htmlSanitizedBlocked: html,
      htmlFilePath: htmlPath,
      sanitizedVersion: version,
      attachments: atts,
    );
  }

  // Fallback lookup that ignores uid_validity (use latest updated row)
  Future<CachedMessageContent?> getContentAnyUidValidity({
    required String accountEmail,
    required String mailboxPath,
    required int uid,
  }) async {
    final db = await _db;
    final rows = await db.query(
      SQLiteDatabaseHelper.tableMessageContent,
      where: 'account_email=? AND mailbox_path=? AND uid=?',
      whereArgs: [accountEmail, mailboxPath, uid],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final uidValidity = (row['uid_validity'] as int?) ?? 0;
    String? plain;
    String? html;
    String? htmlPath;
    try {
      if (row['plain_text'] != null) {
        plain = utf8.decode(_gz.decode(row['plain_text'] as List<int>));
      }
    } catch (_) {}
    try {
      if (row['html_sanitized_blocked'] != null) {
        html = utf8.decode(
          _gz.decode(row['html_sanitized_blocked'] as List<int>),
        );
      }
      if (row['html_file_path'] != null) {
        htmlPath = row['html_file_path'] as String?;
      }
    } catch (_) {}
    final version =
        (row['sanitized_version'] is int)
            ? row['sanitized_version'] as int
            : int.tryParse(row['sanitized_version']?.toString() ?? '1') ?? 1;

    final attRows = await db.query(
      SQLiteDatabaseHelper.tableMessageAttachments,
      where: 'account_email=? AND mailbox_path=? AND uid_validity=? AND uid=?',
      whereArgs: [accountEmail, mailboxPath, uidValidity, uid],
      orderBy: 'id ASC',
    );
    final atts = attRows.map(CachedAttachment.fromMap).toList();

    if (kDebugMode) {
      int htmlLen = html?.length ?? 0;
      bool exists = false;
      int size = -1;
      try {
        if (htmlPath != null && htmlPath.isNotEmpty) {
          final f = File(htmlPath);
          exists = f.existsSync();
          if (exists) size = f.statSync().size;
        }
      } catch (_) {}
      // ignore: avoid_print
      print(
        'STORE:getContentAny uid=$uid box=$mailboxPath v=$version htmlLen=$htmlLen htmlPath=$htmlPath exists=$exists size=$size',
      );
    }

    return CachedMessageContent(
      plainText: plain,
      htmlSanitizedBlocked: html,
      htmlFilePath: htmlPath,
      sanitizedVersion: version,
      attachments: atts,
    );
  }

  Future<void> purgeInvalidUidValidity({
    required String accountEmail,
    required String mailboxPath,
    required int currentUidValidity,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        SQLiteDatabaseHelper.tableMessageContent,
        where: 'account_email=? AND mailbox_path=? AND uid_validity<>?',
        whereArgs: [accountEmail, mailboxPath, currentUidValidity],
      );
      await txn.delete(
        SQLiteDatabaseHelper.tableMessageAttachments,
        where: 'account_email=? AND mailbox_path=? AND uid_validity<>?',
        whereArgs: [accountEmail, mailboxPath, currentUidValidity],
      );
    });
  }

  // Utility to save attachment bytes to a deterministic, collision-safe path
  // Enterprise-grade: stable identity suffixing to avoid overwrites when filenames repeat
  Future<String> saveAttachmentBytes({
    required String accountEmail,
    required String mailboxPath,
    required int uidValidity,
    required int uid,
    required String fileName,
    required List<int> bytes,
    String? uniquePartId, // e.g., ContentInfo.fetchId
    String? contentId, // from part header 'content-id'
    String? mimeType,
    int? size,
  }) async {
    // Local helpers
    String sanitizeName(String n) {
      var s =
          (n.isEmpty ? 'attachment' : n)
              .replaceAll(RegExp(r'[\\/:*?\"<>|]'), '_')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
      if (s.isEmpty) s = 'attachment';
      // keep reasonable length for FS
      if (s.length > 80) s = s.substring(0, 80);
      return s;
    }

    bool isPdfBytes(List<int> b) =>
        b.length >= 5 &&
        b[0] == 0x25 &&
        b[1] == 0x50 &&
        b[2] == 0x44 &&
        b[3] == 0x46 &&
        b[4] == 0x2D;

    bool looksPdfByHint() {
      final m = (mimeType ?? '').toLowerCase();
      final name = fileName.toLowerCase();
      return name.endsWith('.pdf') ||
          m == 'application/pdf' ||
          m == 'application/x-pdf' ||
          m.contains('pdf');
    }

    List<int>? normalizePdfBytesIfNeeded(List<int> input) {
      try {
        if (isPdfBytes(input)) return null; // already proper PDF

        // Try to interpret as text and decode base64 variants
        String asText = '';
        try {
          asText = utf8.decode(input, allowMalformed: true);
        } catch (_) {}

        if (asText.isNotEmpty) {
          // Full-string base64
          final cleaned = asText.replaceAll(RegExp(r'\s'), '');
          final isB64 =
              cleaned.length >= 20 &&
              cleaned.length % 4 == 0 &&
              RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(cleaned);
          if (isB64) {
            try {
              final decoded = base64.decode(cleaned);
              if (isPdfBytes(decoded)) return decoded;
            } catch (_) {}
          }

          // data:...;base64,<payload>
          final lower = asText.toLowerCase();
          final idx = lower.indexOf('base64,');
          if (idx != -1) {
            final payload = asText.substring(idx + 'base64,'.length);
            final cleaned2 = payload.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');
            if (cleaned2.isNotEmpty) {
              try {
                final decoded = base64.decode(cleaned2);
                if (isPdfBytes(decoded)) return decoded;
              } catch (_) {}
            }
          }

          // Embedded base64 segment starting with JVBERi0
          final jv = asText.indexOf('JVBERi0');
          if (jv != -1) {
            int end = jv;
            while (end < asText.length &&
                RegExp(r'[A-Za-z0-9+/=]').hasMatch(asText[end])) {
              end++;
            }
            final seg = asText.substring(jv, end).replaceAll(RegExp(r'\s'), '');
            if (seg.isNotEmpty && seg.length % 4 == 0) {
              try {
                final decoded = base64.decode(seg);
                if (isPdfBytes(decoded)) return decoded;
              } catch (_) {}
            }
          }
        }

        // Binary scan for %PDF- after junk
        for (int i = 0; i + 4 < input.length; i++) {
          if (input[i] == 0x25 &&
              input[i + 1] == 0x50 &&
              input[i + 2] == 0x44 &&
              input[i + 3] == 0x46 &&
              input[i + 4] == 0x2D) {
            return input.sublist(i);
          }
        }
      } catch (_) {}
      return null; // could not normalize
    }

    String extOf(String n) {
      final i = n.lastIndexOf('.');
      if (i > 0 && i < n.length - 1) return n.substring(i);
      return '';
    }

    String baseOf(String n) {
      final i = n.lastIndexOf('.');
      if (i > 0) return n.substring(0, i);
      return n;
    }

    String slug(String s) {
      final t = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '');
      if (t.isEmpty) return 'id';
      return t.length > 10 ? t.substring(0, 10) : t;
    }

    // Best-practice: normalize PDF attachments before saving (handles base64/data URI/junk prefix)
    if (looksPdfByHint()) {
      final normalized = normalizePdfBytesIfNeeded(bytes);
      if (normalized != null) {
        bytes = normalized;
        size = bytes.length;
        if (kDebugMode) {
          // ignore: avoid_print
          print(
            'STORE:normalizePDF name=$fileName -> normalized ${bytes.length} bytes',
          );
        }
      }
    }

    final base = await getApplicationCacheDirectory();
    final safeBox = mailboxPath.replaceAll('/', '_');
    final dir = Directory(
      p.join(
        base.path,
        'offline_attachments',
        accountEmail,
        safeBox,
        '$uidValidity',
        '$uid',
      ),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final sanitized = sanitizeName(fileName);
    final baseName = baseOf(sanitized);
    final ext = extOf(sanitized);

    String suffix;
    if (uniquePartId != null && uniquePartId.trim().isNotEmpty) {
      suffix = '__fid-${slug(uniquePartId)}';
    } else if (contentId != null && contentId.trim().isNotEmpty) {
      suffix = '__cid-${slug(contentId)}';
    } else if (size != null && size > 0) {
      suffix = '__sz-$size';
    } else {
      // last resort: small random nonce to avoid collisions
      final r = DateTime.now().microsecondsSinceEpoch
          .remainder(0xFFFFFF)
          .toRadixString(16);
      suffix = '__r-$r';
    }

    String candidate = '$baseName$suffix$ext';
    var dest = File(p.join(dir.path, candidate));

    // If a file with same name exists and content differs in length, add a nonce
    if (await dest.exists()) {
      try {
        final st = await dest.stat();
        final existingLen = st.size;
        final newLen = bytes.length;
        if (existingLen != newLen) {
          final r = DateTime.now().millisecondsSinceEpoch
              .remainder(0xFFFF)
              .toRadixString(16);
          candidate = '$baseName${suffix}__$r$ext';
          dest = File(p.join(dir.path, candidate));
        }
      } catch (_) {}
    }

    // Atomic write: write to temp then rename
    final tmp = File(p.join(dir.path, '.$candidate.part'));
    await tmp.writeAsBytes(bytes, flush: true);
    try {
      await tmp.rename(dest.path);
    } catch (_) {
      // Fallback: copy and delete temp
      await dest.writeAsBytes(bytes, flush: true);
      try {
        await tmp.delete();
      } catch (_) {}
    }

    if (kDebugMode) {
      // ignore: avoid_print
      print(
        'STORE:saveAttachmentBytes uid=$uid -> ${dest.path} (${bytes.length} bytes)',
      );
    }
    return dest.path;
  }

  // Materialize sanitized HTML inner body to a full HTML file with CSP and adaptive CSS
  Future<String> saveOfflineHtmlDocument({
    required String accountEmail,
    required String mailboxPath,
    required int uidValidity,
    required int uid,
    required String sanitizedInnerHtml,
    required bool blockRemote,
  }) async {
    final base = await getApplicationCacheDirectory();
    final safeBox = mailboxPath.replaceAll('/', '_');
    final dir = Directory(
      p.join(base.path, 'offline_html', accountEmail, safeBox, '$uidValidity'),
    );
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(p.join(dir.path, 'msg_$uid.html'));
    final doc = _wrapOfflineHtml(
      blockRemote: blockRemote,
      innerHtml: sanitizedInnerHtml,
    );
    await file.writeAsString(doc, flush: true);
    if (kDebugMode) {
      try {
        final st = await file.stat();
        // ignore: avoid_print
        print(
          'STORE:saveOfflineHtmlDocument uid=$uid -> ${file.path} (${st.size} bytes)',
        );
      } catch (_) {}
    }
    return file.path;
  }

  String _wrapOfflineHtml({
    required bool blockRemote,
    required String innerHtml,
  }) {
    final csp = _csp(blockRemote);
    final css = _adaptiveBaseCss();
    return '<!doctype html>'
        '<html>'
        '<head>'
        '<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />'
        '<meta http-equiv="Content-Security-Policy" content="$csp" />'
        '<style>$css</style>'
        '</head>'
        '<body class="wb-body"><div class="wb-container">$innerHtml</div></body>'
        '</html>';
  }

  String _csp(bool blocked) {
    final imgSrc =
        blocked
            ? "img-src 'self' data: about: cid:;"
            : "img-src 'self' data: about: cid: http: https:;";
    return [
      "default-src 'none';",
      "base-uri 'none';",
      "form-action 'none';",
      "frame-ancestors 'none';",
      "script-src 'none';",
      "object-src 'none';",
      "connect-src 'none';",
      imgSrc,
      "style-src 'unsafe-inline';",
      "media-src data:;",
      "font-src data:;",
      "frame-src about:;",
    ].join(' ');
  }

  String _adaptiveBaseCss() {
    // Force a light, readable theme for offline HTML to avoid black-on-black issues
    return '''
      :root { color-scheme: light; }
      html, body { margin:0; padding:0; width:100%; overflow-x:hidden; background:#ffffff; color:#1b1c1f; }
      * { box-sizing: border-box; }
      .wb-container { max-width: 100vw; width:100%; overflow-x:hidden; }
      body { font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Helvetica Neue', Arial, sans-serif; line-height:1.5; font-size:15px; overflow-wrap:anywhere; word-break:break-word; -webkit-text-size-adjust: 100%; }
      img, video, iframe { max-width:100% !important; height:auto !important; }
      table { max-width:100% !important; width:100% !important; }
      td, th { word-break: break-word; }
      pre, code { white-space:pre-wrap !important; word-break:break-word !important; }
      a { text-decoration:none; color:#1a73e8; }
      blockquote { border-left:4px solid #1a73e8; background:#f3f6fb; padding:8px 12px; margin:8px 0; }
    ''';
  }

  // Remove a message's cached content and attachments (and files)
  Future<void> removeMessageCache({
    required String accountEmail,
    required String mailboxPath,
    required int uidValidity,
    required int uid,
  }) async {
    final db = await _db;
    final attRows = await db.query(
      SQLiteDatabaseHelper.tableMessageAttachments,
      where: 'account_email=? AND mailbox_path=? AND uid_validity=? AND uid=?',
      whereArgs: [accountEmail, mailboxPath, uidValidity, uid],
    );
    for (final r in attRows) {
      final pth = r['file_path'] as String?;
      if (pth != null && pth.isNotEmpty) {
        try {
          await File(pth).delete();
        } catch (_) {}
      }
    }
    // delete html file
    final msgRows = await db.query(
      SQLiteDatabaseHelper.tableMessageContent,
      where: 'account_email=? AND mailbox_path=? AND uid_validity=? AND uid=?',
      whereArgs: [accountEmail, mailboxPath, uidValidity, uid],
      limit: 1,
    );
    if (msgRows.isNotEmpty) {
      final htmlPath = msgRows.first['html_file_path'] as String?;
      if (htmlPath != null && htmlPath.isNotEmpty) {
        try {
          await File(htmlPath).delete();
        } catch (_) {}
      }
    }
    await db.delete(
      SQLiteDatabaseHelper.tableMessageAttachments,
      where: 'account_email=? AND mailbox_path=? AND uid_validity=? AND uid=?',
      whereArgs: [accountEmail, mailboxPath, uidValidity, uid],
    );
    await db.delete(
      SQLiteDatabaseHelper.tableMessageContent,
      where: 'account_email=? AND mailbox_path=? AND uid_validity=? AND uid=?',
      whereArgs: [accountEmail, mailboxPath, uidValidity, uid],
    );
  }

  // Enforce retention by TTL and size budget (LRU by updated_at)
  Future<void> enforceRetention({
    int maxTotalBytes = 1024 * 1024 * 1024, // 1GB default
    int maxAgeMs = 90 * 24 * 60 * 60 * 1000, // 90 days
  }) async {
    try {
      final db = await _db;
      final rows = await db.query(SQLiteDatabaseHelper.tableMessageContent);
      final now = DateTime.now().millisecondsSinceEpoch;

      // Build entries with sizes
      final entries = <_CacheEntry>[];
      int total = 0;
      for (final r in rows) {
        final account = (r['account_email'] ?? '') as String;
        final box = (r['mailbox_path'] ?? '') as String;
        final uidValidity = (r['uid_validity'] as int?) ?? 0;
        final uid = (r['uid'] as int?) ?? -1;
        final updated = (r['updated_at'] as int?) ?? 0;
        int size = 0;
        final htmlPath = r['html_file_path'] as String?;
        if (htmlPath != null && htmlPath.isNotEmpty) {
          try {
            final st = await File(htmlPath).stat();
            size += st.size;
          } catch (_) {}
        } else {
          // Account for in-DB html/plain blobs roughly using length
          try {
            final plain = r['plain_text'] as List<int>?;
            if (plain != null) size += plain.length;
            final html = r['html_sanitized_blocked'] as List<int>?;
            if (html != null) size += html.length;
          } catch (_) {}
        }
        final atts = await db.query(
          SQLiteDatabaseHelper.tableMessageAttachments,
          where:
              'account_email=? AND mailbox_path=? AND uid_validity=? AND uid=?',
          whereArgs: [account, box, uidValidity, uid],
        );
        for (final a in atts) {
          final pth = a['file_path'] as String?;
          if (pth != null && pth.isNotEmpty) {
            try {
              final st = await File(pth).stat();
              size += st.size;
            } catch (_) {}
          } else {
            final sz = a['size_bytes'];
            if (sz is int) {
              size += sz;
            } else {
              size += int.tryParse(sz?.toString() ?? '0') ?? 0;
            }
          }
        }
        entries.add(_CacheEntry(account, box, uidValidity, uid, updated, size));
        total += size;
      }

      // First remove by TTL
      for (final e
          in entries.where((e) => now - e.updatedAt > maxAgeMs).toList()) {
        await removeMessageCache(
          accountEmail: e.account,
          mailboxPath: e.box,
          uidValidity: e.uidValidity,
          uid: e.uid,
        );
        total -= e.size;
      }

      // Recompute remaining entries (simple approach: refetch rows)
      if (total > maxTotalBytes) {
        final rows2 = await db.query(SQLiteDatabaseHelper.tableMessageContent);
        final list = <_CacheEntry>[];
        for (final r in rows2) {
          final account = (r['account_email'] ?? '') as String;
          final box = (r['mailbox_path'] ?? '') as String;
          final uidValidity = (r['uid_validity'] as int?) ?? 0;
          final uid = (r['uid'] as int?) ?? -1;
          final updated = (r['updated_at'] as int?) ?? 0;
          // Approximate sizes again quickly (skip expensive per-file stats)
          int size = 0;
          final htmlPath = r['html_file_path'] as String?;
          if (htmlPath != null && htmlPath.isNotEmpty) {
            try {
              final st = await File(htmlPath).stat();
              size += st.size;
            } catch (_) {}
          }
          list.add(_CacheEntry(account, box, uidValidity, uid, updated, size));
        }
        list.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        for (final e in list) {
          if (total <= maxTotalBytes) break;
          await removeMessageCache(
            accountEmail: e.account,
            mailboxPath: e.box,
            uidValidity: e.uidValidity,
            uid: e.uid,
          );
          total -= e.size;
        }
      }
    } catch (_) {}
  }

  // Sanitize HTML in isolate for large messages
  static Future<String> sanitizeHtmlInIsolate(String rawHtml) async {
    if (!kIsWeb && rawHtml.length > 100 * 1024) {
      // 100KB threshold for isolate
      return compute(_isolateSanitizeHtml, rawHtml);
    } else {
      // For small HTML or web platform, sanitize inline
      return _isolateSanitizeHtml(rawHtml);
    }
  }

  static String _isolateSanitizeHtml(String rawHtml) {
    // Basic sanitization - in real app this would call HtmlEnhancer
    // For now, simple regex-based approach for isolate compatibility
    String sanitized = rawHtml;

    // Remove script tags
    sanitized = sanitized.replaceAll(
      RegExp(
        r'<script[^>]*>.*?</script>',
        caseSensitive: false,
        multiLine: true,
        dotAll: true,
      ),
      '',
    );

    // Remove event handlers like onload=, onclick=, etc. with quoted values
    sanitized = sanitized.replaceAll(
      RegExp("\\s+on\\w+\\s*=\\s*['\"][^'\"]*['\"]", caseSensitive: false),
      '',
    );

    // Neutralize javascript: links
    sanitized = sanitized.replaceAll(
      RegExp("href\\s*=\\s*['\"]javascript:", caseSensitive: false),
      'href="#"',
    );

    // Block remote images
    sanitized = sanitized.replaceAll(
      RegExp("src\\s*=\\s*['\"]https?://[^'\"]*", caseSensitive: false),
      'src="about:blank"',
    );

    return sanitized;
  }
}

class _CacheEntry {
  final String account;
  final String box;
  final int uidValidity;
  final int uid;
  final int updatedAt;
  final int size;
  _CacheEntry(
    this.account,
    this.box,
    this.uidValidity,
    this.uid,
    this.updatedAt,
    this.size,
  );
}
