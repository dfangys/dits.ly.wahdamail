import 'package:collection/collection.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

class InbocAppBar extends StatefulWidget {
  const InbocAppBar({
    super.key,
    required this.message,
    required this.mailbox,
  });

  final MimeMessage message;
  final Mailbox mailbox;

  @override
  State<InbocAppBar> createState() => _InbocAppBarState();
}

class _InbocAppBarState extends State<InbocAppBar> with SingleTickerProviderStateMixin {
  bool isStarred = false;
  late AnimationController _starAnimationController;
  late Animation<double> _starAnimation;

  @override
  void initState() {
    super.initState();
    isStarred = widget.message.isFlagged;

    // Initialize animation controller for star button
    _starAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _starAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_starAnimationController);
  }

  @override
  void dispose() {
    _starAnimationController.dispose();
    super.dispose();
  }

  final controller = Get.find<MailBoxController>();

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return AppBar(
      backgroundColor: AppTheme.surfaceColor,
      elevation: 0,
      scrolledUnderElevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      leading: Hero(
        tag: 'back_button',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: Get.back,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ),
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message.decodeSubject() ?? 'No Subject',
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimaryColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (isTablet)
            Text(
              widget.mailbox.name.capitalizeFirst ?? widget.mailbox.name,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondaryColor,
              ),
            ),
        ],
      ),
      actions: [
        // Star/Favorite button with animation
        AnimatedBuilder(
          animation: _starAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _starAnimation.value,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isStarred
                      ? AppTheme.starColor.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: IconButton(
                  icon: Icon(
                    isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isStarred ? AppTheme.starColor : Colors.grey,
                    size: 24,
                  ),
                  onPressed: () async {
                    // Toggle star status with animation
                    if (!isStarred) {
                      _starAnimationController.forward(from: 0.0);
                    }

                    setState(() {
                      isStarred = !isStarred;
                    });

                    // Update flag in backend
                    controller.updateFlag([widget.message], controller.mailBoxInbox);
                  },
                  tooltip: isStarred ? 'Remove star' : 'Add star',
                  splashRadius: 24,
                ),
              ),
            );
          },
        ),

        // Reply button
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(50),
          ),
          child: IconButton(
            icon: const Icon(Icons.reply_rounded, size: 22),
            color: AppTheme.primaryColor,
            onPressed: () {
              // Navigate to reply screen
              Get.toNamed('/compose', arguments: {
                'replyTo': widget.message,
                'action': 'reply',
              });
            },
            tooltip: 'Reply',
            splashRadius: 24,
          ),
        ),

        // More options menu
        Container(
          margin: const EdgeInsets.only(left: 4, right: 8),
          decoration: BoxDecoration(
            color: AppTheme.backgroundColor,
            borderRadius: BorderRadius.circular(50),
          ),
          child: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            offset: const Offset(0, 8),
            onSelected: (value) {
              switch (value) {
                case 'reply_all':
                  Get.toNamed('/compose', arguments: {
                    'replyTo': widget.message,
                    'action': 'replyAll',
                  });
                  break;
                case 'forward':
                  Get.toNamed('/compose', arguments: {
                    'replyTo': widget.message,
                    'action': 'forward',
                  });
                  break;
                case 'move':
                  _showMoveDialog();
                  break;
                case 'delete':
                  _showDeleteConfirmation();
                  break;
                case 'mark_unread':
                  controller.markAsUnread([widget.message], widget.mailbox);
                  Get.back();
                  break;
              }
            },
            itemBuilder: (context) => [
              _buildPopupMenuItem('reply_all', Icons.reply_all_rounded, 'Reply All'),
              _buildPopupMenuItem('forward', Icons.forward_rounded, 'Forward'),
              _buildPopupMenuItem('move', Icons.folder_outlined, 'Move to...'),
              _buildPopupMenuItem('mark_unread', Icons.mark_email_unread_rounded, 'Mark as unread'),
              _buildPopupMenuItem('delete', Icons.delete_outline_rounded, 'Delete', isDestructive: true),
            ],
          ),
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(
      String value,
      IconData icon,
      String text,
      {bool isDestructive = false}
      ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDestructive ? Colors.red : AppTheme.primaryColor,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: isDestructive ? Colors.red : AppTheme.textPrimaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showMoveDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Move Message',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ),

            const Divider(),

            // Mailbox list
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (var box in controller.mailboxes
                      .whereNot((e) => e == widget.mailbox)
                      .toList())
                    InkWell(
                      onTap: () {
                        controller.moveMails(
                          [widget.message],
                          widget.mailbox,
                          box,
                        );
                        Get.back();
                        Get.back(); // Return to previous screen after moving
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getMailboxIcon(box.name),
                                size: 20,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              box.name.capitalizeFirst ?? box.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textPrimaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Cancel button
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: AppTheme.textPrimaryColor,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Cancel",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.red[700],
              size: 24,
            ),
            const SizedBox(width: 8),
            const Text('Delete Message'),
          ],
        ),
        content: const Text('Are you sure you want to delete this message? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              // Delete message
              controller.deleteMessages([widget.message], widget.mailbox);
              Get.back(); // Close dialog
              Get.back(); // Return to previous screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 4,
      ),
    );
  }

  IconData _getMailboxIcon(String name) {
    name = name.toLowerCase();
    switch (name) {
      case 'inbox':
        return Icons.inbox_rounded;
      case 'sent':
        return Icons.send_rounded;
      case 'spam':
      case 'junk':
        return Icons.error_rounded;
      case 'trash':
        return Icons.delete_rounded;
      case 'drafts':
        return Icons.drafts_rounded;
      case 'flagged':
        return Icons.flag_rounded;
      default:
        return Icons.folder_rounded;
    }
  }
}
