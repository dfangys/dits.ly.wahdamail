import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/compose/widgets/compose_modal.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import '../../../../app/controllers/mailbox_controller.dart';

class ViewMessageBottomNav extends StatelessWidget {
  ViewMessageBottomNav({
    super.key,
    required this.mailbox,
    required this.message,
  });

  final MimeMessage message;
  final Mailbox mailbox;
  final mailController = Get.find<MailBoxController>();

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: AppTheme.bottomNavShadow,
      ),
      padding: EdgeInsets.only(
        top: 12,
        bottom: 12 + MediaQuery.of(context).padding.bottom,
        left: isTablet ? 24 : 16,
        right: isTablet ? 24 : 16,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildActionButton(
              context: context,
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              onTap: () => _showDeleteConfirmation(context),
              destructive: true,
            ),
            _buildActionButton(
              context: context,
              icon: Icons.reply_rounded,
              label: 'Reply',
              onTap: () => _navigateToCompose('reply'),
            ),
            // _buildActionButton(
            //   context: context,
            //   icon: Icons.mark_email_unread_rounded,
            //   label: 'Unread',
            //   onTap: () {
            //     // controller.markAsUnread([message], mailbox);
            //     Get.back();
            //   },
            // ),
            _buildActionButton(
              context: context,
              icon: Icons.reply_all_rounded,
              label: 'Reply All',
              onTap: () => _navigateToCompose('reply_all'),
            ),
            _buildActionButton(
              context: context,
              icon: Icons.forward_rounded,
              label: 'Forward',
              onTap: () => _navigateToCompose('forward'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 12 : 8,
          vertical: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isTablet ? 48 : 40,
              height: isTablet ? 48 : 40,
              decoration: BoxDecoration(
                color: destructive
                    ? Colors.red.withValues(alpha : 0.1)
                    : AppTheme.primaryColor.withValues(alpha : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: isTablet ? 24 : 20,
                color: destructive ? Colors.red : AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: destructive ? Colors.red : AppTheme.textPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCompose(String type) {
    ComposeModal.show(Get.context!, arguments: {
      'message': message,
      'type': type,
    });
  }

  void _showDeleteConfirmation(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text(
          'Delete Message',
          style: TextStyle(color: AppTheme.textPrimaryColor),
        ),
        message: const Text(
          'Are you sure you want to delete this message?',
          style: TextStyle(color: AppTheme.textSecondaryColor),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              mailController.deleteMails([message], mailbox);
              Get.back(); // Close dialog
              Get.back(); // Return to inbox
            },
            isDestructiveAction: true,
            child: const Text('Delete'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () {
            Get.back();
          },
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}