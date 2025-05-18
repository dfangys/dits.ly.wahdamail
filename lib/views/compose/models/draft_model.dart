import 'package:enough_mail/enough_mail.dart';

/// Model class for storing draft email information
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

  /// List of recipient email addresses in "Name <email>" format
  final List<String> to;

  /// List of CC recipient email addresses in "Name <email>" format
  final List<String> cc;

  /// List of BCC recipient email addresses in "Name <email>" format
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
    );
  }

  /// Convert draft to a map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'message_id': messageId,
      'subject': subject,
      'body': body,
      'is_html': isHtml ? 1 : 0,
      'to_recipients': to.join('||'),
      'cc_recipients': cc.join('||'),
      'bcc_recipients': bcc.join('||'),
      'attachment_paths': attachmentPaths.join('||'),
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'is_scheduled': isScheduled ? 1 : 0,
      'scheduled_for': scheduledFor?.millisecondsSinceEpoch,
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
      to: map['to_recipients'] != null && map['to_recipients'].isNotEmpty
          ? map['to_recipients'].split('||')
          : <String>[],
      cc: map['cc_recipients'] != null && map['cc_recipients'].isNotEmpty
          ? map['cc_recipients'].split('||')
          : <String>[],
      bcc: map['bcc_recipients'] != null && map['bcc_recipients'].isNotEmpty
          ? map['bcc_recipients'].split('||')
          : <String>[],
      attachmentPaths: map['attachment_paths'] != null && map['attachment_paths'].isNotEmpty
          ? map['attachment_paths'].split('||')
          : <String>[],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
      isScheduled: map['is_scheduled'] == 1,
      scheduledFor: map['scheduled_for'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['scheduled_for'])
          : null,
    );
  }

  /// Create a draft from a MimeMessage
  factory DraftModel.fromMimeMessage(MimeMessage message) {
    // Extract recipients
    final to = message.to?.map((addr) =>
    '${addr.personalName ?? ''} <${addr.email}>').toList() ?? <String>[];
    final cc = message.cc?.map((addr) =>
    '${addr.personalName ?? ''} <${addr.email}>').toList() ?? <String>[];
    final bcc = message.bcc?.map((addr) =>
    '${addr.personalName ?? ''} <${addr.email}>').toList() ?? <String>[];

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
      messageId = message.getHeaderValue('message-id')?.replaceAll('<', '').replaceAll('>', '');
    } catch (e) {
      // Fallback if header extraction fails
      messageId = null;
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

    // Set content
    builder.addMultipartAlternative(
      htmlText: isHtml ? body : null,
      plainText: isHtml ? _stripHtml(body) : body,
    );

    // Set sender
    builder.from = [MailAddress(account.name, account.email)];

    // Build message
    return builder.buildMimeMessage();
  }

  /// Parse addresses from "Name <email>" format
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
}
