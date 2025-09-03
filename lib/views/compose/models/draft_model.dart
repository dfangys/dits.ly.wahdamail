import 'package:enough_mail/enough_mail.dart';

/// Model class for storing draft email information with enhanced features
class DraftModel {
  /// Unique identifier for the draft
  final int? id;

  /// Message ID for linking with IMAP server
  final String? messageId;

  /// Email subject
  final String subject;

  /// Email body content
  final String body;

  /// Whether the body is HTML format
  final bool isHtml;

  /// List of recipient email addresses in `Name <email>` format
  final List<String> to;

  /// List of CC recipient email addresses in `Name <email>` format
  final List<String> cc;

  /// List of BCC recipient email addresses in `Name <email>` format
  final List<String> bcc;

  /// List of file paths for attachments
  final List<String> attachmentPaths;

  /// When the draft was created
  final DateTime createdAt;

  /// When the draft was last updated
  final DateTime updatedAt;

  /// Whether the draft is scheduled to be sent later
  final bool isScheduled;

  /// When the draft is scheduled to be sent (null if not scheduled)
  final DateTime? scheduledFor;

  /// Version number for tracking changes and conflict resolution
  final int version;

  /// Category for organizing drafts (e.g., "work", "personal")
  final String category;

  /// Priority level (0-5, with 5 being highest)
  final int priority;

  /// Whether this draft has been synced with the server
  final bool isSynced;

  /// Server UID for this draft (if synced)
  final int? serverUid;

  /// Whether this draft has unsaved changes
  final bool isDirty;

  /// Tags for additional organization
  final List<String> tags;

  /// Last error encountered when saving this draft
  final String? lastError;

  DraftModel({
    this.id,
    this.messageId,
    required this.subject,
    required this.body,
    required this.isHtml,
    required this.to,
    required this.cc,
    required this.bcc,
    required this.attachmentPaths,
    required this.createdAt,
    required this.updatedAt,
    this.isScheduled = false,
    this.scheduledFor,
    this.version = 1,
    this.category = 'default',
    this.priority = 0,
    this.isSynced = false,
    this.serverUid,
    this.isDirty = true,
    this.tags = const [],
    this.lastError,
  });

  /// Create a copy of this draft with updated fields
  DraftModel copyWith({
    int? id,
    String? messageId,
    String? subject,
    String? body,
    bool? isHtml,
    List<String>? to,
    List<String>? cc,
    List<String>? bcc,
    List<String>? attachmentPaths,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isScheduled,
    DateTime? scheduledFor,
    int? version,
    String? category,
    int? priority,
    bool? isSynced,
    int? serverUid,
    bool? isDirty,
    List<String>? tags,
    String? lastError,
  }) {
    return DraftModel(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      isHtml: isHtml ?? this.isHtml,
      to: to ?? this.to,
      cc: cc ?? this.cc,
      bcc: bcc ?? this.bcc,
      attachmentPaths: attachmentPaths ?? this.attachmentPaths,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isScheduled: isScheduled ?? this.isScheduled,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      version: version ?? this.version,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      isSynced: isSynced ?? this.isSynced,
      serverUid: serverUid ?? this.serverUid,
      isDirty: isDirty ?? this.isDirty,
      tags: tags ?? this.tags,
      lastError: lastError ?? this.lastError,
    );
  }

  /// Mark this draft as dirty (has unsaved changes)
  DraftModel markDirty() {
    return copyWith(isDirty: true);
  }

  /// Mark this draft as clean (no unsaved changes)
  DraftModel markClean() {
    return copyWith(isDirty: false);
  }

  /// Increment the version of this draft
  DraftModel incrementVersion() {
    return copyWith(version: version + 1);
  }

  /// Mark this draft as synced with the server
  DraftModel markSynced(int serverUid) {
    return copyWith(isSynced: true, serverUid: serverUid);
  }

  /// Mark this draft as having a sync error
  DraftModel markSyncError(String error) {
    return copyWith(isSynced: false, lastError: error);
  }

  /// Add a tag to this draft
  DraftModel addTag(String tag) {
    final newTags = List<String>.from(tags);
    if (!newTags.contains(tag)) {
      newTags.add(tag);
    }
    return copyWith(tags: newTags);
  }

  /// Remove a tag from this draft
  DraftModel removeTag(String tag) {
    final newTags = List<String>.from(tags);
    newTags.remove(tag);
    return copyWith(tags: newTags);
  }

  /// Convert draft to a map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'message_id': messageId,
      'subject': subject,
      'body': body,
      'is_html': isHtml ? 1 : 0,
      'to_address': to.join('||'),
      'cc_address': cc.join('||'),
      'bcc_address': bcc.join('||'),
      'attachment_paths': attachmentPaths.join('||'),
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'is_scheduled': isScheduled ? 1 : 0,
      'scheduled_for': scheduledFor?.millisecondsSinceEpoch,
      'version': version,
      'category': category,
      'priority': priority,
      'is_synced': isSynced ? 1 : 0,
      'server_uid': serverUid,
      'is_dirty': isDirty ? 1 : 0,
      'tags': tags.join('||'),
      'last_error': lastError,
    };
  }

  /// Create a draft from a database map
  factory DraftModel.fromMap(Map<String, dynamic> map) {
    return DraftModel(
      id: map['id'],
      messageId: map['message_id'],
      subject: map['subject'] ?? '',
      body: map['body'] ?? '',
      isHtml: map['is_html'] == 1,
      to:
          map['to_address'] != null && map['to_address'].isNotEmpty
              ? map['to_address'].split('||')
              : <String>[],
      cc:
          map['cc_address'] != null && map['cc_address'].isNotEmpty
              ? map['cc_address'].split('||')
              : <String>[],
      bcc:
          map['bcc_address'] != null && map['bcc_address'].isNotEmpty
              ? map['bcc_address'].split('||')
              : <String>[],
      attachmentPaths:
          map['attachment_paths'] != null && map['attachment_paths'].isNotEmpty
              ? map['attachment_paths'].split('||')
              : <String>[],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
      isScheduled: map['is_scheduled'] == 1,
      scheduledFor:
          map['scheduled_for'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['scheduled_for'])
              : null,
      version: map['version'] ?? 1,
      category: map['category'] ?? 'default',
      priority: map['priority'] ?? 0,
      isSynced: map['is_synced'] == 1,
      serverUid: map['server_uid'],
      isDirty: map['is_dirty'] == 1,
      tags:
          map['tags'] != null && map['tags'].isNotEmpty
              ? map['tags'].split('||')
              : <String>[],
      lastError: map['last_error'],
    );
  }

  /// Create a draft from a MimeMessage
  factory DraftModel.fromMimeMessage(MimeMessage message) {
    // Extract recipients
    final to =
        message.to
            ?.map((addr) => '${addr.personalName ?? ''} <${addr.email}>')
            .toList() ??
        <String>[];
    final cc =
        message.cc
            ?.map((addr) => '${addr.personalName ?? ''} <${addr.email}>')
            .toList() ??
        <String>[];
    final bcc =
        message.bcc
            ?.map((addr) => '${addr.personalName ?? ''} <${addr.email}>')
            .toList() ??
        <String>[];

    // Extract content
    final htmlContent = message.decodeTextHtmlPart();
    final plainContent = message.decodeTextPlainPart();
    final isHtml = htmlContent != null;
    final body = htmlContent ?? plainContent ?? '';

    // Extract subject
    final subject = message.decodeSubject() ?? '';

    // Get message ID - using the correct method for enough_mail 2.1.6
    String? messageId;
    try {
      messageId = message
          .getHeaderValue('message-id')
          ?.replaceAll('<', '')
          .replaceAll('>', '');
    } catch (e) {
      // Fallback if header extraction fails
      messageId = null;
    }

    // Extract any custom headers for enhanced draft features
    String category = 'default';
    int priority = 0;
    List<String> tags = [];

    try {
      // Try to extract category from X-Category header
      final categoryHeader = message.getHeaderValue('X-Category');
      if (categoryHeader != null && categoryHeader.isNotEmpty) {
        category = categoryHeader;
      }

      // Try to extract priority from X-Priority header
      final priorityHeader = message.getHeaderValue('X-Priority');
      if (priorityHeader != null) {
        priority = int.tryParse(priorityHeader) ?? 0;
      }

      // Try to extract tags from X-Tags header
      final tagsHeader = message.getHeaderValue('X-Tags');
      if (tagsHeader != null && tagsHeader.isNotEmpty) {
        tags = tagsHeader.split(',').map((tag) => tag.trim()).toList();
      }
    } catch (e) {
      // Ignore header extraction errors
    }

    // Create draft model
    return DraftModel(
      messageId: messageId,
      subject: subject,
      body: body,
      isHtml: isHtml,
      to: to,
      cc: cc,
      bcc: bcc,
      attachmentPaths: [], // Attachments need to be downloaded separately
      createdAt: message.decodeDate() ?? DateTime.now(),
      updatedAt: DateTime.now(),
      category: category,
      priority: priority,
      tags: tags,
      isSynced: true, // Since it came from the server
      serverUid: message.uid,
      isDirty: false, // Initially not dirty since it just came from the server
    );
  }

  /// Convert draft to a MimeMessage
  MimeMessage toMimeMessage(MailAccount account) {
    // Create message builder
    final builder = MessageBuilder();

    // Add recipients
    builder.to = _parseAddresses(to);
    builder.cc = _parseAddresses(cc);
    builder.bcc = _parseAddresses(bcc);

    // Set subject
    builder.subject = subject;

    // Set content (avoid empty multipart/alternative)
    final String htmlCandidate = isHtml ? body.trim() : '';
    final String plainCandidate =
        isHtml ? _stripHtml(body).trim() : body.trim();
    if (htmlCandidate.isEmpty && plainCandidate.isEmpty) {
      builder.addMultipartAlternative(htmlText: null, plainText: ' ');
    } else {
      builder.addMultipartAlternative(
        htmlText: htmlCandidate.isNotEmpty ? htmlCandidate : null,
        plainText: plainCandidate.isNotEmpty ? plainCandidate : null,
      );
    }

    // Set sender: prefer a real display name; if absent or equals email, omit name to keep RFC-5322 compliant simple addr-spec
    final displayName = (account.name).trim();
    if (displayName.isEmpty ||
        displayName.toLowerCase() == account.email.toLowerCase()) {
      builder.from = [MailAddress('', account.email)];
    } else {
      builder.from = [MailAddress(displayName, account.email)];
    }

    // Add custom headers for enhanced draft features
    builder.addHeader('X-Category', category);
    builder.addHeader('X-Priority', priority.toString());
    if (tags.isNotEmpty) {
      builder.addHeader('X-Tags', tags.join(','));
    }
    builder.addHeader('X-Draft-Version', version.toString());

    // Build message
    return builder.buildMimeMessage();
  }

  /// Parse addresses from `Name <email>` format
  List<MailAddress> _parseAddresses(List<String> addresses) {
    return addresses.map((addr) {
      final match = RegExp(r'(.*) <(.*)>').firstMatch(addr);
      if (match != null && match.group(1)!.isNotEmpty) {
        return MailAddress(match.group(1)!, match.group(2)!);
      } else {
        return MailAddress('', addr.replaceAll(RegExp(r'<|>'), ''));
      }
    }).toList();
  }

  /// Strip HTML tags from text
  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  /// Check if this draft has enough content to be saved
  bool get hasSaveableContent {
    return subject.isNotEmpty ||
        body.isNotEmpty ||
        to.isNotEmpty ||
        cc.isNotEmpty ||
        bcc.isNotEmpty ||
        attachmentPaths.isNotEmpty;
  }

  /// Get a summary of this draft for display
  String get summary {
    final recipientCount = to.length + cc.length + bcc.length;
    final hasSubject = subject.isNotEmpty;
    final hasBody = body.isNotEmpty;
    final hasAttachments = attachmentPaths.isNotEmpty;

    final parts = <String>[];

    if (hasSubject) {
      parts.add(subject);
    }

    if (recipientCount > 0) {
      parts.add('$recipientCount recipients');
    }

    if (hasAttachments) {
      parts.add('${attachmentPaths.length} attachments');
    }

    if (hasBody) {
      const previewLength = 50;
      final preview = _stripHtml(body).replaceAll('\n', ' ');
      parts.add(
        preview.length > previewLength
            ? '${preview.substring(0, previewLength)}...'
            : preview,
      );
    }

    return parts.join(' • ');
  }
}
