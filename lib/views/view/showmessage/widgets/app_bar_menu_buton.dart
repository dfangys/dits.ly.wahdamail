import 'package:flutter/material.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:get/get.dart';

class InboxAppBarMenuButton extends StatelessWidget {
  const InboxAppBarMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(           // <void> fixes the inference error
      icon: const Icon(
        Icons.more_vert_rounded,
        color: AppTheme.primaryColor,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      position: PopupMenuPosition.under,
      offset: const Offset(0, 8),
      itemBuilder: (context) => <PopupMenuEntry<void>>[
        _buildPopupMenuItem(
          icon: Icons.inbox_rounded,
          text: 'Move to Inbox',
          onTap: () {
            // markAsInbox();
          },
        ),
        _buildPopupMenuItem(
          icon: Icons.drafts_rounded,
          text: 'Move to Draft',
          onTap: () {
            // markAsDraft();
          },
        ),
        _buildPopupMenuItem(
          icon: Icons.delete_rounded,
          text: 'Move to Trash',
          onTap: () {
            // markAsTrash();
          },
        ),
        _buildPopupMenuItem(
          icon: Icons.report_rounded,
          text: 'Move to Spam',
          onTap: () {
            // markAsSpam();
          },
        ),
        const PopupMenuDivider(),           // Never <: void, so this is OK
        _buildPopupMenuItem(
          icon: Icons.archive_rounded,
          text: 'Archive',
          onTap: () {
            // archive();
          },
        ),
        _buildPopupMenuItem(
          icon: Icons.mark_email_read_rounded,
          text: 'Mark as read',
          onTap: () {
            // markAsRead();
          },
        ),
        _buildPopupMenuItem(
          icon: Icons.mark_email_unread_rounded,
          text: 'Mark as unread',
          onTap: () {
            // markAsUnread();
          },
        ),
      ],
    );
  }

  PopupMenuItem<void> _buildPopupMenuItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return PopupMenuItem<void>(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}