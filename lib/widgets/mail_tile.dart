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

class _MailTileState extends State<MailTile> with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  final settingController = Get.find<SettingController>();
  final selectionController = Get.find<SelectionController>();
  final mailboxController = Get.find<MailBoxController>();
  final cacheManager = CacheManager.instance;

  // Animation and feedback state
  bool _isDeleting = false;
  bool _isProcessing = false;
  late AnimationController _feedbackController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // Cached computed values to avoid recomputation
  late final String _senderName;
  late final String _senderEmail;
  late final bool _hasAttachments;
  late final DateTime? _messageDate;
  late final String _subject;
  late final String _preview;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _computeCachedValues();
    
    // Initialize animation controllers for smooth feedback
    _feedbackController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _feedbackController,
      curve: Curves.easeInOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.3,
    ).animate(CurvedAnimation(
      parent: _feedbackController,
      curve: Curves.easeInOut,
    ));
  }

  void _computeCachedValues() {
    // ENHANCED: Compute sender information with better envelope handling
    if ((["sent", "drafts"].contains(widget.mailBox.name.toLowerCase())) &&
        widget.message.to != null &&
        widget.message.to!.isNotEmpty) {
      // For sent/drafts, show recipient
      final recipient = widget.message.to!.first;
      _senderName = recipient.personalName?.isNotEmpty == true 
          ? recipient.personalName! 
          : (recipient.email.isNotEmpty 
              ? recipient.email.split('@').first 
              : 'Unknown Recipient');
      _senderEmail = recipient.email;
    } else {
      // For inbox and other folders, show sender
      MailAddress? sender;
      
      // Try envelope first (most reliable)
      if (widget.message.envelope?.from != null && widget.message.envelope!.from!.isNotEmpty) {
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
                .map((r) => r.personalName?.isNotEmpty == true ? r.personalName! : r.email)
                .take(2) // Limit to first 2 recipients
                .join(', ');
            _senderEmail = recipients.first.email;
          } else {
            _senderName = "Recipients";
            _senderEmail = "recipients@unknown.com";
          }
        } else {
          // For received messages, show sender with enhanced logic
          _senderName = sender.personalName?.isNotEmpty == true 
              ? sender.personalName! 
              : (sender.email.isNotEmpty 
                  ? sender.email.split('@').first 
                  : 'Unknown Sender');
          _senderEmail = sender.email;
        }
      } else {
        _senderName = "Unknown Sender";
        _senderEmail = "unknown@unknown.com";
      }
    }

    // ENHANCED: Cache other computed values with better fallbacks
    _hasAttachments = widget.message.hasAttachments == true;
    
    // ENHANCED: Better date handling with comprehensive fallback chain
    DateTime? messageDate;
    
    // Try multiple date sources in order of preference
    try {
      // 1. Try message.decodeDate() first
      messageDate = widget.message.decodeDate();
      if (messageDate != null && kDebugMode) {
        print('📧 Date from message.decodeDate(): $messageDate');
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error in message.decodeDate(): $e');
      }
    }
    
    // 2. Try envelope date if message date failed
    if (messageDate == null) {
      try {
        messageDate = widget.message.envelope?.date;
        if (messageDate != null && kDebugMode) {
          print('📧 Date from envelope.date: $messageDate');
        }
      } catch (e) {
        if (kDebugMode) {
          print('📧 Error in envelope.date: $e');
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
            print('📧 Date from header parsing: $messageDate');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('📧 Error parsing date header: $e');
        }
      }
    }
    
    // 4. Last resort: use current time but log the issue
    if (messageDate == null) {
      messageDate = DateTime.now();
      if (kDebugMode) {
        print('📧 WARNING: Using current time as fallback for message date');
        print('📧 Message UID: ${widget.message.uid}');
        print('📧 Message envelope: ${widget.message.envelope}');
        print('📧 Message headers: ${widget.message.headers}');
      }
    }
    
    _messageDate = messageDate;
    
    // ENHANCED: Use enough_mail_app pattern for proper subject decoding
    final decodedSubject = widget.message.decodeSubject();
    if (decodedSubject?.isNotEmpty == true) {
      _subject = decodedSubject!;
    } else {
      // Fallback to envelope subject
      String? subject = widget.message.envelope?.subject;
      if (subject == null || subject.isEmpty) {
        subject = widget.message.getHeaderValue('subject');
      }
      _subject = subject?.isNotEmpty == true ? subject! : 'No Subject';
    }
    
    _preview = _generatePreview();
    
    if (kDebugMode) {
      print('📧 Mail tile computed: sender="$_senderName", subject="$_subject", date=$_messageDate');
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
    // ENHANCED: Use enough_mail_app pattern for rich preview generation
    
    // 1. Try plain text content first (most reliable)
    try {
      final plainText = widget.message.decodeTextPlainPart();
      if (plainText?.isNotEmpty == true) {
        return _cleanPreviewText(plainText!);
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error decoding plain text: $e');
      }
    }
    
    // 2. Try HTML content and strip tags
    try {
      final htmlContent = widget.message.decodeTextHtmlPart();
      if (htmlContent?.isNotEmpty == true) {
        final cleanHtml = _stripHtmlTags(htmlContent!);
        if (cleanHtml.isNotEmpty) {
          return _cleanPreviewText(cleanHtml);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('📧 Error decoding HTML: $e');
      }
    }
    
    // 3. Try cached content from cache manager
    try {
      final cachedContent = cacheManager.getCachedMessageContent(widget.message);
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
    
    // 4. Check for attachments and provide meaningful preview
    if (_hasAttachments) {
      return "📎 Message with attachments";
    }
    
    // 5. Try envelope or headers for preview hints
    if (widget.message.envelope != null) {
      final previewHeader = widget.message.getHeaderValue('x-preview') ??
                           widget.message.getHeaderValue('x-microsoft-exchange-diagnostics');
      if (previewHeader != null && previewHeader.isNotEmpty) {
        return _cleanPreviewText(previewHeader);
      }
    }
    
    // 6. Fallback based on message characteristics
    if (widget.message.isTextMessage == true) {
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
    final cleanContent = content
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
    
    final bool isUnread = !widget.message.isSeen;
    final bool hasFlagged = widget.message.isFlagged;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Obx(() {
      final isSelected = selectionController.selected.contains(widget.message);
      
      // Wrap with smooth animations for real-time feedback
      return AnimatedBuilder(
        animation: _feedbackController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedOpacity(
              opacity: _isDeleting ? _fadeAnimation.value : 1.0,
              duration: const Duration(milliseconds: 300),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: _isProcessing 
                      ? theme.colorScheme.primary.withOpacity(0.1)
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
                ),
              ),
            ),
          );
        },
      );
    });
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
          print('📧 Successfully marked as read: ${widget.message.decodeSubject()}');
        }
      } else {
        await realtimeService.markMessageAsUnread(widget.message);
        if (kDebugMode) {
          print('📧 Successfully marked as unread: ${widget.message.decodeSubject()}');
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
    _showActionFeedback(
      'Deleting...',
      Icons.delete,
      Colors.red,
    );
    
    // OPTIMISTIC UPDATE: Start fade-out animation immediately
    setState(() {
      _isDeleting = true;
    });
    
    try {
      // Perform server action
      await realtimeService.deleteMessage(widget.message);
      
      // Success feedback
      _showActionFeedback(
        'Message deleted',
        Icons.check,
        Colors.green,
      );
      
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
    // Archive functionality - move to archive folder
    try {
      Get.snackbar(
        'Info',
        'Archive functionality coming soon',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to archive message',
        backgroundColor: Colors.red,
        colorText: Colors.white,
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
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
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
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

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.primaryColor.withValues(alpha: 0.1)
            : (isDarkMode ? Colors.grey.shade900 : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: theme.primaryColor, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Slidable(
        key: ValueKey(message.uid ?? message.sequenceId),
        startActionPane: _buildStartActionPane(),
        endActionPane: _buildEndActionPane(),
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
              padding: const EdgeInsets.all(16),
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
                                  fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
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
                                  fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        
                        // Subject line with indicators
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                subject,
                                style: TextStyle(
                                  fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                                  fontSize: 14,
                                  color: theme.textTheme.bodyMedium?.color,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Attachment indicator
                            if (hasAttachments) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.attach_file,
                                  size: 14,
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
                        const SizedBox(height: 4),
                        
                        // Preview text
                        Text(
                          preview,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.textTheme.bodySmall?.color,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  Widget _buildLeadingWidget() {
    final selectionController = Get.find<SelectionController>();
    
    if (selectionController.isSelecting) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Checkbox(
          value: isSelected,
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
  }

  void _toggleSelection() {
    final selectionController = Get.find<SelectionController>();
    if (isSelected) {
      selectionController.selected.remove(message);
    } else {
      selectionController.selected.add(message);
    }
  }

  // Build start action pane based on settings (Left-to-Right swipe)
  ActionPane? _buildStartActionPane() {
    final settingController = Get.find<SettingController>();
    final action = settingController.swipeGesturesLTR.value;
    
    return ActionPane(
      motion: const ScrollMotion(),
      children: [_buildSwipeAction(action, isStartPane: true)],
    );
  }

  // Build end action pane based on settings (Right-to-Left swipe)
  ActionPane? _buildEndActionPane() {
    final settingController = Get.find<SettingController>();
    final action = settingController.swipeGesturesRTL.value;
    
    return ActionPane(
      motion: const ScrollMotion(),
      children: [_buildSwipeAction(action, isStartPane: false)],
    );
  }

  // Build individual swipe action based on action type
  SlidableAction _buildSwipeAction(String actionType, {required bool isStartPane}) {
    switch (actionType) {
      case 'read_unread':
        return SlidableAction(
          onPressed: (context) => onMarkAsRead(),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          icon: isUnread ? Icons.mark_email_read : Icons.mark_email_unread,
          label: isUnread ? 'Read' : 'Unread',
        );
      case 'flag':
        return SlidableAction(
          onPressed: (context) => onToggleFlag(),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          icon: hasFlagged ? Icons.flag : Icons.flag_outlined,
          label: hasFlagged ? 'Unflag' : 'Flag',
        );
      case 'delete':
        return SlidableAction(
          onPressed: (context) => onDeleteMessage(),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          icon: Icons.delete,
          label: 'Delete',
        );
      case 'archive':
        return SlidableAction(
          onPressed: (context) => onArchiveMessage(),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          icon: Icons.archive,
          label: 'Archive',
        );
      default:
        return SlidableAction(
          onPressed: (context) => onMarkAsRead(),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          icon: isUnread ? Icons.mark_email_read : Icons.mark_email_unread,
          label: isUnread ? 'Read' : 'Unread',
        );
    }
  }

}

