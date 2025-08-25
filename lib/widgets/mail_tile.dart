import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/views/compose/compose.dart';
import '../app/controllers/selection_controller.dart';
import '../app/controllers/settings_controller.dart';
import '../utills/funtions.dart';
import '../utills/theme/app_theme.dart';
import '../services/cache_manager.dart';
import '../services/realtime_update_service.dart';

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

class _MailTileState extends State<MailTile> with AutomaticKeepAliveClientMixin {
  final settingController = Get.find<SettingController>();
  final selectionController = Get.find<SelectionController>();
  final mailboxController = Get.find<MailBoxController>();
  final cacheManager = CacheManager.instance;

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
  }

  void _computeCachedValues() {
    // Compute sender information
    if ((["sent", "drafts"].contains(widget.mailBox.name.toLowerCase())) &&
        widget.message.to != null &&
        widget.message.to!.isNotEmpty) {
      _senderName = widget.message.to!.first.personalName ?? 
                   widget.message.to!.first.email.split('@').first;
      _senderEmail = widget.message.to!.first.email;
    } else if (widget.message.from != null && widget.message.from!.isNotEmpty) {
      _senderName = widget.message.from!.first.personalName ?? 
                   widget.message.from!.first.email.split('@').first;
      _senderEmail = widget.message.from!.first.email;
    } else {
      _senderName = "Unknown";
      _senderEmail = "";
    }

    // Cache other computed values
    _hasAttachments = widget.message.hasAttachments();
    _messageDate = widget.message.decodeDate();
    _subject = widget.message.decodeSubject() ?? 'No Subject';
    _preview = _generatePreview();
  }

  String _generatePreview() {
    // Try cached content first
    final cachedContent = cacheManager.getCachedMessageContent(widget.message);
    if (cachedContent != null && cachedContent.isNotEmpty) {
      return _extractPreviewFromContent(cachedContent);
    }

    // Try to get text content from message
    try {
      // Try plain text first
      final textPart = widget.message.decodeTextPlainPart();
      if (textPart != null && textPart.trim().isNotEmpty) {
        return _extractPreviewFromContent(textPart);
      }

      // Try HTML content
      final htmlPart = widget.message.decodeTextHtmlPart();
      if (htmlPart != null && htmlPart.trim().isNotEmpty) {
        return _extractPreviewFromContent(htmlPart);
      }

      // Try to extract from message body parts
      if (widget.message.body != null) {
        final bodyText = widget.message.body.toString();
        if (bodyText.isNotEmpty) {
          return _extractPreviewFromContent(bodyText);
        }
      }

      // Try subject as fallback
      final subject = widget.message.decodeSubject();
      if (subject != null && subject.isNotEmpty) {
        return 'Subject: $subject';
      }
    } catch (e) {
      // If all else fails, return a default message
    }

    return 'No preview available';
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
      
      return OptimizedMailTileContent(
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
      );
    });
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[date.weekday - 1];
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectionController = Get.find<SelectionController>();
    final mailboxController = Get.find<MailBoxController>();

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
                        
                        // Subject line
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
                            if (hasAttachments)
                              Icon(
                                Icons.attach_file,
                                size: 16,
                                color: theme.primaryColor,
                              ),
                            if (hasFlagged)
                              Icon(
                                Icons.flag,
                                size: 16,
                                color: Colors.orange,
                              ),
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
          onPressed: (context) => _markAsRead(),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          icon: isUnread ? Icons.mark_email_read : Icons.mark_email_unread,
          label: isUnread ? 'Read' : 'Unread',
        );
      case 'flag':
        return SlidableAction(
          onPressed: (context) => _toggleFlag(),
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          icon: hasFlagged ? Icons.flag : Icons.flag_outlined,
          label: hasFlagged ? 'Unflag' : 'Flag',
        );
      case 'delete':
        return SlidableAction(
          onPressed: (context) => _deleteMessage(),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          icon: Icons.delete,
          label: 'Delete',
        );
      case 'archive':
        return SlidableAction(
          onPressed: (context) => _archiveMessage(),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          icon: Icons.archive,
          label: 'Archive',
        );
      default:
        return SlidableAction(
          onPressed: (context) => _markAsRead(),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          icon: isUnread ? Icons.mark_email_read : Icons.mark_email_unread,
          label: isUnread ? 'Read' : 'Unread',
        );
    }
  }

  void _markAsRead() async {
    final realtimeService = RealtimeUpdateService.instance;
    try {
      if (isUnread) {
        await realtimeService.markMessageAsRead(message);
      } else {
        await realtimeService.markMessageAsUnread(message);
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update message status',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _toggleFlag() async {
    final realtimeService = RealtimeUpdateService.instance;
    try {
      if (hasFlagged) {
        await realtimeService.unflagMessage(message);
      } else {
        await realtimeService.flagMessage(message);
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to update flag status',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _deleteMessage() async {
    final realtimeService = RealtimeUpdateService.instance;
    try {
      await realtimeService.deleteMessage(message);
      Get.snackbar(
        'Success',
        'Message deleted',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete message',
        backgroundColor: Colors.red,
        colorText: Colors.white,
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
}
