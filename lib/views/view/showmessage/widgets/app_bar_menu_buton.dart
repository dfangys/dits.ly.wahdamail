import 'package:flutter/material.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

class InboxAppBarMenuButton extends StatelessWidget {
  const InboxAppBarMenuButton({
    super.key,
    this.onMoveToInbox,
    this.onMoveToDraft,
    this.onMoveToTrash,
    this.onMoveToSpam,
  });

  final VoidCallback? onMoveToInbox;
  final VoidCallback? onMoveToDraft;
  final VoidCallback? onMoveToTrash;
  final VoidCallback? onMoveToSpam;

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(50),
      ),
      child: PopupMenuButton(
        icon: const Icon(
          Icons.more_vert_rounded,
          color: AppTheme.primaryColor,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
        offset: const Offset(0, 8),
        position: PopupMenuPosition.under,
        itemBuilder: (context) => [
          _buildMenuItem(
            icon: Icons.inbox_rounded,
            text: 'Move to Inbox',
            onTap: onMoveToInbox,
          ),
          _buildMenuItem(
            icon: Icons.drafts_rounded,
            text: 'Move to Draft',
            onTap: onMoveToDraft,
          ),
          _buildMenuItem(
            icon: Icons.delete_outline_rounded,
            text: 'Move to Trash',
            onTap: onMoveToTrash,
            isDestructive: true,
          ),
          _buildMenuItem(
            icon: Icons.report_problem_outlined,
            text: 'Move to Spam',
            onTap: onMoveToSpam,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  PopupMenuItem _buildMenuItem({
    required IconData icon,
    required String text,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    return PopupMenuItem(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDestructive
                    ? Colors.red.withOpacity(0.1)
                    : AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isDestructive ? Colors.red : AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                color: isDestructive ? Colors.red : AppTheme.textPrimaryColor,
                fontWeight: FontWeight.w500,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
