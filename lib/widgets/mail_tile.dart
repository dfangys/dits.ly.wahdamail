import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/app/controllers/selection_controller.dart';
import 'package:wahda_bank/services/realtime_update_service.dart';
import '../services/cache_manager.dart';
import 'package:wahda_bank/services/feature_flags.dart';
import 'package:wahda_bank/services/draft_sync_service.dart';
import 'package:wahda_bank/features/settings/presentation/data/swap_data.dart';

class MailTile extends StatefulWidget {
  const MailTile({
    super.key,
    required this.onTap,
    required this.message,
    required this.mailBox,
  });

  final VoidCallback? onTap;
  final MimeMessage message;
  final Mailbox mailBox;

  @override
  State<MailTile> createState() => _MailTileState();
}

class _MailTileState extends State<MailTile>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final settingController = Get.find<SettingController>();
  final selectionController = Get.find<SelectionController>();
  final mailboxController = Get.find<MailBoxController>();
  final cacheManager = CacheManager.instance;

  // Animation and feedback state
  bool _isDeleting = false;
  final bool _isProcessing = false;
  late AnimationController _feedbackController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // Cached computed values to avoid recomputation (mutable to allow refresh on meta change)
  String _senderName = '';
  String _senderEmail = '';
  bool _hasAttachments = false;
  DateTime? _messageDate;
  String _subject = '';
  String _preview = '';

  ValueNotifier<int>? _metaNotifier;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _computeCachedValues();

    // If sender/subject are still missing, attempt fast hydration from storage (and log source)
    if (_senderName == 'Unknown Sender' || _subject == 'No Subject') {
      _hydrateSenderSubjectIfMissing();
    }

    // Listen for per-message meta updates (e.g., preview backfill)
    try {
      if (FeatureFlags.instance.perTileNotifiersEnabled) {
        _metaNotifier = mailboxController.getMessageMetaNotifier(
          widget.mailBox,
          widget.message,
        );
        _metaNotifier?.addListener(_onMetaChanged);
      }
    } catch (_) {}

    // Initialize animation controllers for smooth feedback
    _feedbackController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _feedbackController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _feedbackController, curve: Curves.easeInOut),
    );
  }

  void _computeCachedValues() {
    // ENHANCED: Compute sender information with better envelope handling
    if ((["sent", "drafts"].contains(widget.mailBox.name.toLowerCase())) &&
        widget.message.to != null &&
        widget.message.to!.isNotEmpty) {
      // For sent/drafts, show recipient
      final recipient = widget.message.to!.first;
      _senderName =
          recipient.personalName?.isNotEmpty == true
              ? recipient.personalName!
              : (recipient.email.isNotEmpty
                  ? recipient.email.split('@').first
                  : 'Unknown Recipient');
      _senderEmail = recipient.email;
    } else {
      // For inbox and other folders, show sender
      MailAddress? sender;

      // Try envelope first (most reliable)
      if (widget.message.envelope?.from != null &&
          widget.message.envelope!.from!.isNotEmpty) {
        sender = widget.message.envelope!.from!.first;
      }
      // Fallback to message.from
      else if (widget.message.from != null && widget.message.from!.isNotEmpty) {
        sender = widget.message.from!.first;
      }
      // Last resort: try to parse from headers
      else {
        final fromHeader = widget.message.getHeaderValue('from');
        if (fromHeader != null && fromHeader.isNotEmpty) {
          try {
            sender = MailAddress.parse(fromHeader);
          } catch (e) {
            // If parsing fails, create a basic MailAddress
            sender = MailAddress('', fromHeader);
          }
        }
      }

      if (sender != null) {
        // Use enough_mail_app pattern for smart sender display
        if (_isSentMessage()) {
          // For sent messages, show recipients
          final recipients = widget.message.to ?? [];
          if (recipients.isNotEmpty) {
            _senderName = recipients
                .map(
                  (r) =>
                      r.personalName?.isNotEmpty == true
                          ? r.personalName!
                          : r.email,
                )
                .take(2) // Limit to first 2 recipients
                .join(', ');
            _senderEmail = recipients.first.email;
          } else {
            _senderName = "Recipients";
            _senderEmail = "recipients@unknown.com";
          }
        } else {
          // For received messages, show sender with enhanced logic
          _senderName =
              sender.personalName?.isNotEmpty == true
                  ? sender.personalName!
                  : (sender.email.isNotEmpty
                      ? sender.email.split('@').first
                      : 'Unknown Sender');
          _senderEmail = sender.email;
        }
      } else {
        // Final fallback: try to parse raw headers for sender
        try {
          final rawFrom = widget.message.getHeaderValue('from');
          if (rawFrom != null && rawFrom.trim().isNotEmpty) {
            try {
              final parsed = MailAddress.parse(rawFrom);
              _senderName =
                  parsed.personalName?.isNotEmpty == true
                      ? parsed.personalName!
                      : (parsed.email.isNotEmpty
                          ? parsed.email.split('@').first
                          : 'Unknown Sender');
              _senderEmail = parsed.email;
              if (kDebugMode) {
                debugPrint(
                  '📧 Tile sender fallback via raw headers: $_senderName <$_senderEmail>',
                );
              }
            } catch (_) {
              _senderName = rawFrom.trim();
              _senderEmail = rawFrom.trim();
              if (kDebugMode) {
                debugPrint(
                  '📧 Tile sender fallback (raw string): $_senderName',
                );
              }
            }
          } else {
            _senderName = "Unknown Sender";
            _senderEmail = "unknown@unknown.com";
          }
        } catch (_) {
          _senderName = "Unknown Sender";
          _senderEmail = "unknown@unknown.com";
        }
      }
    }

    // ENHANCED: Fast-path attachment flag via persisted header if present
    final hasAttHeader = widget.message.getHeaderValue('x-has-attachments');
    if (hasAttHeader != null) {
      _hasAttachments = hasAttHeader == '1';
    } else {
      _hasAttachments = widget.message.hasAttachments();
    }

    // DEBUG: Log attachment status for debugging
    if (kDebugMode && _hasAttachments) {
      debugPrint(
        '📎 Message "${widget.message.decodeSubject()}" has attachments',
      );
    }

    // ENHANCED: Better date handling with comprehensive fallback chain
    DateTime? messageDate;

    // Try multiple date sources in order of preference
    try {
      // 1. Try message.decodeDate() first
      messageDate = widget.message.decodeDate();
      if (messageDate != null && kDebugMode) {
        debugPrint('📧 Date from message.decodeDate(): $messageDate');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📧 Error in message.decodeDate(): $e');
      }
    }

    // 2. Try envelope date if message date failed
    if (messageDate == null) {
      try {
        messageDate = widget.message.envelope?.date;
        if (messageDate != null && kDebugMode) {
          debugPrint('📧 Date from envelope.date: $messageDate');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('📧 Error in envelope.date: $e');
        }
      }
    }

    // 3. Try parsing date header directly
    if (messageDate == null) {
      try {
        final dateHeader = widget.message.getHeaderValue('date');
        if (dateHeader != null && dateHeader.isNotEmpty) {
          messageDate = DateTime.tryParse(dateHeader);
          if (messageDate != null && kDebugMode) {
            debugPrint('📧 Date from header parsing: $messageDate');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('📧 Error parsing date header: $e');
        }
      }
    }

    // 4. Last resort: use current time but log the issue
    if (messageDate == null) {
      messageDate = DateTime.now();
      if (kDebugMode) {
        debugPrint(
          '📧 WARNING: Using current time as fallback for message date',
        );
        debugPrint('📧 Message UID: ${widget.message.uid}');
        debugPrint('📧 Message envelope: ${widget.message.envelope}');
        debugPrint('📧 Message headers: ${widget.message.headers}');
      }
    }

    _messageDate = messageDate;

    // ENHANCED: Use enough_mail_app pattern for proper subject decoding
    final decodedSubject = widget.message.decodeSubject();
    if (decodedSubject?.isNotEmpty == true) {
      _subject = decodedSubject!;
      if (kDebugMode) {
        debugPrint('📧 Tile subject via decodeSubject: $_subject');
      }
    } else {
      // Fallback to envelope subject
      String? subject = widget.message.envelope?.subject;
      if (subject == null || subject.isEmpty) {
        subject = widget.message.getHeaderValue('subject');
        if (subject != null && subject.isNotEmpty && kDebugMode) {
          debugPrint('📧 Tile subject via raw header: $subject');
        }
      }
      _subject = subject?.isNotEmpty == true ? subject! : 'No Subject';
    }

    _preview = _generatePreview();

    if (kDebugMode) {
      debugPrint(
        '📧 Mail tile computed: sender="$_senderName", subject="$_subject", date=$_messageDate',
      );
    }
  }

  bool _isSentMessage() {
    // Determine if this is a sent message based on mailbox context
    final controller = Get.find<MailBoxController>();
    final currentMailbox = controller.currentMailbox;

    if (currentMailbox?.name.toLowerCase().contains('sent') == true) {
      return true;
    }

    // Additional check for drafts
    if (currentMailbox?.name.toLowerCase().contains('draft') == true) {
      return true;
    }

    return false;
  }

  String _generatePreview() {
    // ENHANCED: Use persisted preview header first for O(1) preview
    final headerPreview = widget.message.getHeaderValue('x-preview');
    if (headerPreview != null && headerPreview.trim().isNotEmpty) {
      return _cleanPreviewText(headerPreview);
    }

    // 2. Try cached content from cache manager
    try {
      final cachedContent = cacheManager.getCachedMessageContent(
        widget.message,
      );
      if (cachedContent != null && cachedContent.isNotEmpty) {
        final preview = _extractPreviewFromContent(cachedContent);
        if (preview.isNotEmpty && preview != 'No preview available') {
          return preview;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error getting cached content: $e');
      }
    }

    // 3. Try plain text and HTML only if needed (can be heavier)
    try {
      final plainText = widget.message.decodeTextPlainPart();
      if (plainText?.isNotEmpty == true) {
        return _cleanPreviewText(plainText!);
      }
    } catch (_) {}
    try {
      final htmlContent = widget.message.decodeTextHtmlPart();
      if (htmlContent?.isNotEmpty == true) {
        final cleanHtml = _stripHtmlTags(htmlContent!);
        if (cleanHtml.isNotEmpty) {
          return _cleanPreviewText(cleanHtml);
        }
      }
    } catch (_) {}

    // 4. Check for attachments and provide meaningful preview
    if (_hasAttachments) {
      return "📎 Message with attachments";
    }

    // 5. Try envelope or headers for preview hints
    if (widget.message.envelope != null) {
      final previewHeader =
          widget.message.getHeaderValue('x-preview') ??
          widget.message.getHeaderValue('x-microsoft-exchange-diagnostics');
      if (previewHeader != null && previewHeader.isNotEmpty) {
        return _cleanPreviewText(previewHeader);
      }
    }

    // 6. Fallback based on message characteristics
    if (widget.message.isTextMessage()) {
      return "Text message";
    }

    return "No preview available";
  }

  String _cleanPreviewText(String text) {
    // Clean and format preview text following enough_mail_app patterns
    return text
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .replaceAll(RegExp(r'[\r\n]+'), ' ') // Remove line breaks
        .trim()
        .substring(0, text.length > 100 ? 100 : text.length); // Limit length
  }

  String _stripHtmlTags(String html) {
    // Simple HTML tag stripping for preview
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'&[a-zA-Z0-9#]+;'), ' ') // Remove HTML entities
        .trim();
  }

  String _extractPreviewFromContent(String content) {
    // Remove HTML tags and extra whitespace
    final cleanContent =
        content
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    // Return first 100 characters
    return cleanContent.length > 100
        ? '${cleanContent.substring(0, 100)}...'
        : cleanContent;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final bool isDraftsBox = widget.mailBox.name.toLowerCase().contains(
      'draft',
    );
    final bool isUnread = isDraftsBox ? false : !widget.message.isSeen;
    final bool hasFlagged = widget.message.isFlagged;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final selectionId = selectionController.selectionIdFor(widget.message);
    return GetBuilder<SelectionController>(
      id: selectionId,
      builder: (sel) {
        final isSelected = sel.isSelected(widget.message);
        // Wrap with smooth animations for real-time feedback
        final animCap = FeatureFlags.instance.animationsCappedEnabled;
        final durFast = Duration(milliseconds: animCap ? 120 : 200);
        final durMedium = Duration(milliseconds: animCap ? 180 : 300);
        return AnimatedBuilder(
          animation: _feedbackController,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: AnimatedOpacity(
                opacity: _isDeleting ? _fadeAnimation.value : 1.0,
                duration: durMedium,
                child: AnimatedContainer(
                  duration: durFast,
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color:
                        _isProcessing
                            ? theme.colorScheme.primary.withValues(alpha: 0.1)
                            : null,
                  ),
                  child: OptimizedMailTileContent(
                    message: widget.message,
                    mailBox: widget.mailBox,
                    isUnread: isUnread,
                    hasFlagged: hasFlagged,
                    isSelected: isSelected,
                    senderName: _senderName,
                    senderEmail: _senderEmail,
                    hasAttachments: _hasAttachments,
                    messageDate: _messageDate,
                    subject: _subject,
                    preview: _preview,
                    onTap: widget.onTap,
                    theme: theme,
                    isDarkMode: isDarkMode,
                    onMarkAsRead: _markAsRead,
                    onToggleFlag: _toggleFlag,
                    onDeleteMessage: _deleteMessage,
                    onArchiveMessage: _archiveMessage,
                    onMarkAsJunk: _markAsJunk,
                    metaNotifier: _metaNotifier,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Action methods for email operations with optimistic updates
  void _markAsRead() async {
    final realtimeService = RealtimeUpdateService.instance;

    // OPTIMISTIC UPDATE: Update UI immediately for instant feedback
    final wasUnread = !widget.message.isSeen;
    setState(() {
      if (wasUnread) {
        widget.message.isSeen = true;
      } else {
        widget.message.isSeen = false;
      }
    });

    // Show immediate visual feedback
    _showActionFeedback(
      wasUnread ? 'Marked as read' : 'Marked as unread',
      wasUnread ? Icons.mark_email_read : Icons.mark_email_unread,
      Colors.blue,
    );

    try {
      // Perform server action in background
      if (wasUnread) {
        await realtimeService.markMessageAsRead(widget.message);
        if (kDebugMode) {
          print(
            '📧 Successfully marked as read: ${widget.message.decodeSubject()}',
          );
        }
      } else {
        await realtimeService.markMessageAsUnread(widget.message);
        if (kDebugMode) {
          print(
            '📧 Successfully marked as unread: ${widget.message.decodeSubject()}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error updating message status: $e');
      }

      // ROLLBACK: Revert optimistic update on error
      setState(() {
        widget.message.isSeen = wasUnread;
      });

      Get.snackbar(
        'Error',
        'Failed to update message: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  void _toggleFlag() async {
    final realtimeService = RealtimeUpdateService.instance;

    // OPTIMISTIC UPDATE: Update UI immediately for instant feedback
    final wasFlagged = widget.message.isFlagged;
    setState(() {
      if (wasFlagged) {
        widget.message.isFlagged = false;
      } else {
        widget.message.isFlagged = true;
      }
    });

    // Show immediate visual feedback
    _showActionFeedback(
      wasFlagged ? 'Unflagged' : 'Flagged',
      wasFlagged ? Icons.flag_outlined : Icons.flag,
      Colors.orange,
    );

    try {
      // Perform server action in background
      if (wasFlagged) {
        await realtimeService.unflagMessage(widget.message);
      } else {
        await realtimeService.flagMessage(widget.message);
      }
    } catch (e) {
      // ROLLBACK: Revert optimistic update on error
      setState(() {
        widget.message.isFlagged = wasFlagged;
      });

      Get.snackbar(
        'Error',
        'Failed to update flag: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  void _deleteMessage() async {
    final realtimeService = RealtimeUpdateService.instance;

    // Show immediate visual feedback with animation
    _showActionFeedback('Deleting...', Icons.delete, Colors.red);

    // OPTIMISTIC UPDATE: Start fade-out animation immediately
    setState(() {
      _isDeleting = true;
    });

    try {
      // Perform server action
      await realtimeService.deleteMessage(widget.message);

      // Success feedback
      _showActionFeedback('Message deleted', Icons.check, Colors.green);

      // Remove from UI after animation
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          // Notify parent to remove from list
          mailboxController.removeMessageFromUI(widget.message, widget.mailBox);
        }
      });
    } catch (e) {
      // ROLLBACK: Revert optimistic update on error
      setState(() {
        _isDeleting = false;
      });

      Get.snackbar(
        'Error',
        'Failed to delete message: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  void _archiveMessage() async {
    // Move message to Archive mailbox with optimistic UI and haptic feedback
    try {
      _showActionFeedback(
        'Archiving...',
        Icons.archive_outlined,
        Colors.orange,
      );
      final archive = mailboxController.mailboxes.firstWhereOrNull(
        (e) => e.isArchive,
      );
      if (archive == null) {
        Get.snackbar(
          'Info',
          'Archive mailbox not found',
          backgroundColor: Colors.blue,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
        return;
      }
      mailboxController.removeMessageFromUI(widget.message, widget.mailBox);
      await mailboxController.moveMails(
        [widget.message],
        widget.mailBox,
        archive,
      );
      _showActionFeedback('Message archived', Icons.check, Colors.green);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to archive message: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  void _markAsJunk() async {
    // Move message to Junk mailbox (spam)
    try {
      _showActionFeedback(
        'Moving to Junk...',
        Icons.report_gmailerrorred,
        const Color(0xFF9C27B0),
      );
      final junk = mailboxController.mailboxes.firstWhereOrNull(
        (e) => e.isJunk,
      );
      if (junk == null) {
        Get.snackbar(
          'Info',
          'Junk mailbox not found',
          backgroundColor: Colors.blue,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
        return;
      }
      mailboxController.removeMessageFromUI(widget.message, widget.mailBox);
      await mailboxController.moveMails([widget.message], widget.mailBox, junk);
      _showActionFeedback('Message moved to Junk', Icons.check, Colors.green);
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to move to Junk: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  // Visual feedback method for smooth user experience
  void _showActionFeedback(String message, IconData icon, Color color) {
    // Trigger haptic feedback
    HapticFeedback.lightImpact();

    // Show subtle animation
    _feedbackController.forward().then((_) {
      _feedbackController.reverse();
    });

    // Show toast-like feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(message, style: const TextStyle(fontSize: 14)),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  void dispose() {
    try {
      _metaNotifier?.removeListener(_onMetaChanged);
    } catch (_) {}
    _feedbackController.dispose();
    super.dispose();
  }

  void _onMetaChanged() {
    if (!mounted) return;
    setState(() {
      // Refresh full cached values when meta changes; this also recalculates
      // sender/subject/date if the envelope became available.
      _computeCachedValues();
      if ((_senderName == 'Unknown Sender' || _subject == 'No Subject')) {
        // Attempt a late hydration from storage if still missing
        _hydrateSenderSubjectIfMissing();
      }
    });
  }

  // Hydrate sender/subject quickly from SQLite if envelope is not yet set
  Future<void> _hydrateSenderSubjectIfMissing() async {
    try {
      final storage = mailboxController.mailboxStorage[widget.mailBox];
      if (storage == null) return;
      final seq = MessageSequence.fromMessage(widget.message);
      final fromDb = await storage.loadMessageEnvelopes(seq);
      if (fromDb.isNotEmpty) {
        final mm = fromDb.first;
        bool changed = false;
        if (widget.message.envelope == null && mm.envelope != null) {
          widget.message.envelope = mm.envelope;
          changed = true;
          if (kDebugMode) {
            debugPrint('📧 Tile hydration: envelope loaded from DB');
          }
        }
        if ((widget.message.from == null || widget.message.from!.isEmpty) &&
            (mm.from?.isNotEmpty ?? false)) {
          widget.message.from = mm.from;
          changed = true;
          if (kDebugMode) {
            debugPrint('📧 Tile hydration: from loaded from DB');
          }
        }
        final subj = mm.decodeSubject() ?? mm.envelope?.subject;
        if ((widget.message.decodeSubject() == null ||
                (widget.message.decodeSubject()?.isEmpty ?? true)) &&
            (subj != null && subj.isNotEmpty)) {
          try {
            widget.message.setHeader('subject', subj);
          } catch (_) {}
          changed = true;
          if (kDebugMode) {
            debugPrint('📧 Tile hydration: subject loaded from DB');
          }
        }
        if (changed) {
          try {
            widget.message.setHeader('x-ready', '1');
          } catch (_) {}
          if (mounted) {
            setState(() => _computeCachedValues());
          }
          try {
            mailboxController.bumpMessageMeta(widget.mailBox, widget.message);
          } catch (_) {}
        }
      } else {
        if (kDebugMode) {
          debugPrint(
            '📧 Tile hydration: DB had no envelope row yet for this message',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('📧 Tile hydration error: $e');
      }
    }
  }
}

class OptimizedMailTileContent extends StatelessWidget {
  const OptimizedMailTileContent({
    super.key,
    required this.message,
    required this.mailBox,
    required this.isUnread,
    required this.hasFlagged,
    required this.isSelected,
    required this.senderName,
    required this.senderEmail,
    required this.hasAttachments,
    required this.messageDate,
    required this.subject,
    required this.preview,
    required this.onTap,
    required this.theme,
    required this.isDarkMode,
    required this.onMarkAsRead,
    required this.onToggleFlag,
    required this.onDeleteMessage,
    required this.onArchiveMessage,
    required this.onMarkAsJunk,
    this.metaNotifier,
  });

  final MimeMessage message;
  final Mailbox mailBox;
  final bool isUnread;
  final bool hasFlagged;
  final bool isSelected;
  final String senderName;
  final String senderEmail;
  final bool hasAttachments;
  final DateTime? messageDate;
  final String subject;
  final String preview;
  final VoidCallback? onTap;
  final ThemeData theme;
  final bool isDarkMode;
  final VoidCallback onMarkAsRead;
  final VoidCallback onToggleFlag;
  final VoidCallback onDeleteMessage;
  final VoidCallback onArchiveMessage;
  final VoidCallback onMarkAsJunk;
  final ValueListenable<int>? metaNotifier;

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    // Today: show time
    if (difference.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    // Yesterday
    else if (difference.inDays == 1) {
      return 'Yesterday';
    }
    // This week: show day name
    else if (difference.inDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[date.weekday - 1];
    }
    // This year: show month and day
    else if (date.year == now.year) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}';
    }
    // Previous years: show full date
    else {
      return '${date.day}/${date.month}/${date.year.toString().substring(2)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectionController = Get.find<SelectionController>();

    // Adapt preview lines for accessibility text scales to prevent overflow in fixed-extent rows.
    final textScale = MediaQuery.of(context).textScaler.scale(14.0) / 14.0;
    final int previewMaxLines = textScale > 1.25 ? 1 : 2;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            isSelected
                ? theme.primaryColor.withValues(alpha: 0.1)
                : (isDarkMode ? Colors.grey.shade900 : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border:
            isSelected ? Border.all(color: theme.primaryColor, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Obx(() {
        final sc = Get.find<SettingController>();
        // Establish reactive dependencies so changes reflect immediately
        final ltr = sc.swipeGesturesLTR.value;
        final rtl = sc.swipeGesturesRTL.value;
        return Slidable(
          key: ValueKey(message.uid ?? message.sequenceId),
          startActionPane: _buildStartActionPaneFor(ltr),
          endActionPane: _buildEndActionPaneFor(rtl),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (selectionController.isSelecting) {
                  _toggleSelection();
                } else {
                  onTap?.call();
                }
              },
              onLongPress: _toggleSelection,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical:
                      FeatureFlags.instance.fixedExtentListEnabled ? 12 : 16,
                ),
                child: Row(
                  children: [
                    // Selection indicator or avatar
                    _buildLeadingWidget(),
                    const SizedBox(width: 12),

                    // Message content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header row with sender and time
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  senderName,
                                  style: TextStyle(
                                    fontWeight:
                                        isUnread
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                    fontSize: 16,
                                    color: theme.textTheme.bodyLarge?.color,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (messageDate != null)
                                Text(
                                  _formatDate(messageDate!),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.textTheme.bodySmall?.color,
                                    fontWeight:
                                        isUnread
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(
                            height:
                                (FeatureFlags.instance.fixedExtentListEnabled &&
                                        (textScale > 1.1))
                                    ? 2
                                    : 4,
                          ),

                          // Subject line with indicators
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  subject,
                                  style: TextStyle(
                                    fontWeight:
                                        isUnread
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                    fontSize: 14,
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Draft sync badge (only in Drafts mailbox)
                              if (mailBox.isDrafts) ...[
                                const SizedBox(width: 4),
                                _DraftSyncBadge(
                                  message: message,
                                  mailbox: mailBox,
                                  theme: theme,
                                ),
                              ],
                              // Thread count pill (if part of a conversation)
                              _ThreadCountPill(
                                key: ValueKey(
                                  message.uid ?? message.sequenceId ?? 0,
                                ),
                                message: message,
                                theme: theme,
                                metaNotifier: metaNotifier,
                              ),

                              // Attachment indicator - Enhanced visibility
                              if (FeatureFlags
                                      .instance
                                      .perTileNotifiersEnabled &&
                                  metaNotifier != null)
                                ValueListenableBuilder<int>(
                                  valueListenable: metaNotifier!,
                                  builder: (context, _, __) {
                                    final ha = message.getHeaderValue(
                                      'x-has-attachments',
                                    );
                                    final hasAtt =
                                        ha == '1' ||
                                        (ha == null ? hasAttachments : false);
                                    return hasAtt
                                        ? Row(
                                          children: [
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: BoxDecoration(
                                                color: theme.primaryColor
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: theme.primaryColor
                                                      .withValues(alpha: 0.3),
                                                  width: 0.5,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.attach_file,
                                                size: 16,
                                                color: theme.primaryColor,
                                              ),
                                            ),
                                          ],
                                        )
                                        : const SizedBox.shrink();
                                  },
                                )
                              else if (hasAttachments) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor.withValues(
                                      alpha: 0.15,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: theme.primaryColor.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.attach_file,
                                    size:
                                        16, // Slightly larger for better visibility
                                    color: theme.primaryColor,
                                  ),
                                ),
                              ],
                              // Flag indicator
                              if (hasFlagged) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.flag,
                                    size: 14,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          SizedBox(
                            height:
                                (FeatureFlags.instance.fixedExtentListEnabled &&
                                        (textScale > 1.1))
                                    ? 2
                                    : 4,
                          ),

                          // Preview text (flexible to avoid vertical overflow)
                          Flexible(
                            child:
                                FeatureFlags.instance.perTileNotifiersEnabled &&
                                        metaNotifier != null
                                    ? ValueListenableBuilder<int>(
                                      valueListenable: metaNotifier!,
                                      builder: (context, _, __) {
                                        final hp = message.getHeaderValue(
                                          'x-preview',
                                        );
                                        final text =
                                            (hp != null && hp.trim().isNotEmpty)
                                                ? hp
                                                : preview;
                                        return ClipRect(
                                          child: Text(
                                            text,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color:
                                                  theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.color,
                                              height: 1.25,
                                            ),
                                            maxLines: previewMaxLines,
                                            overflow: TextOverflow.ellipsis,
                                            softWrap: true,
                                          ),
                                        );
                                      },
                                    )
                                    : ClipRect(
                                      child: Text(
                                        preview,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color:
                                              theme.textTheme.bodySmall?.color,
                                          height: 1.25,
                                        ),
                                        maxLines: previewMaxLines,
                                        overflow: TextOverflow.ellipsis,
                                        softWrap: true,
                                      ),
                                    ),
                          ),
                        ],
                      ),
                    ),

                    // Unread indicator
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildLeadingWidget() {
    final selectionController = Get.find<SelectionController>();

    return Obx(() {
      final selecting = selectionController.selecting.value;
      if (selecting) {
        final checked = selectionController.isSelected(message);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Checkbox(
            value: checked,
            onChanged: (_) => _toggleSelection(),
            activeColor: theme.primaryColor,
          ),
        );
      }

      return CircleAvatar(
        radius: 20,
        backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
        child: Text(
          senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
          style: TextStyle(
            color: theme.primaryColor,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      );
    });
  }

  void _toggleSelection() {
    final selectionController = Get.find<SelectionController>();
    selectionController.toggle(message);
  }

  // Build start action pane (Left-to-Right swipe) for a given action key
  ActionPane _buildStartActionPaneFor(String action) {
    return ActionPane(
      motion: const ScrollMotion(),
      children: [_buildSwipeAction(action, isStartPane: true)],
    );
  }

  // Build end action pane (Right-to-Left swipe) for a given action key
  ActionPane _buildEndActionPaneFor(String action) {
    return ActionPane(
      motion: const ScrollMotion(),
      children: [_buildSwipeAction(action, isStartPane: false)],
    );
  }

  // Build individual swipe action based on action type (normalized via SwapAction enum)
  SlidableAction _buildSwipeAction(
    String actionType, {
    required bool isStartPane,
  }) {
    final action = getSwapActionFromString(actionType);
    switch (action) {
      case SwapAction.readUnread:
        return SlidableAction(
          onPressed: (context) => onMarkAsRead(),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          icon: isUnread ? Icons.mark_email_read : Icons.mark_email_unread,
          label: isUnread ? 'Read' : 'Unread',
        );
      case SwapAction.toggleFlag:
        return SlidableAction(
          onPressed: (context) => onToggleFlag(),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          icon: hasFlagged ? Icons.flag : Icons.flag_outlined,
          label: hasFlagged ? 'Unflag' : 'Flag',
        );
      case SwapAction.delete:
        return SlidableAction(
          onPressed: (context) => onDeleteMessage(),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          icon: Icons.delete,
          label: 'Delete',
        );
      case SwapAction.archive:
        return SlidableAction(
          onPressed: (context) => onArchiveMessage(),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          icon: Icons.archive,
          label: 'Archive',
        );
      case SwapAction.markAsJunk:
        return SlidableAction(
          onPressed: (context) => onMarkAsJunk(),
          backgroundColor: const Color(0xFF9C27B0),
          foregroundColor: Colors.white,
          icon: Icons.report_gmailerrorred,
          label: 'Junk',
        );
    }
  }
}

class _DraftSyncBadge extends StatelessWidget {
  const _DraftSyncBadge({
    required this.message,
    required this.mailbox,
    required this.theme,
  });
  final MimeMessage message;
  final Mailbox mailbox;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    // Listen to DraftSyncService RxMap via Obx for live updates
    return Obx(() {
      // Observe the RxMap directly so Obx rebuilds when it changes
      final stateMap = DraftSyncService.instance.states;
      final key = DraftSyncService.instance.keyFor(mailbox, message);
      final state = stateMap[key] ?? DraftSyncBadgeState.idle;
      switch (state) {
        case DraftSyncBadgeState.syncing:
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.28),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Syncing',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        case DraftSyncBadgeState.synced:
          return Icon(
            Icons.check_circle,
            size: 16,
            color: Colors.green.shade600,
          );
        case DraftSyncBadgeState.failed:
          return Icon(
            Icons.error_outline,
            size: 16,
            color: Colors.red.shade600,
          );
        case DraftSyncBadgeState.idle:
          return const SizedBox.shrink();
      }
    });
  }
}

class _ThreadCountPill extends StatelessWidget {
  const _ThreadCountPill({
    super.key,
    required this.message,
    required this.theme,
    this.metaNotifier,
  });

  final MimeMessage message;
  final ThemeData theme;
  final ValueListenable<int>? metaNotifier;

  int _computeThreadCount() {
    // Prefer header (fast path)
    final header = message.getHeaderValue('x-thread-count');
    int? count = header != null ? int.tryParse(header) : null;
    if (count == null || count <= 1) {
      try {
        final seq = message.threadSequence;
        final c = seq == null ? 0 : seq.toList().length;
        count = c;
      } catch (_) {}
    }
    return count ?? 0;
  }

  Widget _buildPill() {
    final tc = _computeThreadCount();
    if (tc <= 1) return const SizedBox.shrink();
    return Row(
      children: [
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: theme.primaryColor.withValues(alpha: 0.28),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.forum, size: 14, color: theme.primaryColor),
              const SizedBox(width: 4),
              Text(
                '$tc',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (metaNotifier != null) {
      return ValueListenableBuilder<int>(
        valueListenable: metaNotifier!,
        builder: (_, __, ___) => _buildPill(),
      );
    }
    return _buildPill();
  }
}
