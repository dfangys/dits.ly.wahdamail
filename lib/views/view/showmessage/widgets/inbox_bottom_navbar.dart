import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/compose/compose.dart';
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
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: AppTheme.bottomNavShadow,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildActionButton(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            onTap: () => _showDeleteConfirmation(context),
          ),
          _buildActionButton(
            icon: Icons.reply_rounded,
            label: 'Reply',
            onTap: () => _navigateToCompose('reply'),
          ),
          _buildActionButton(
            icon: Icons.reply_all_rounded,
            label: 'Reply All',
            onTap: () => _navigateToCompose('reply_all'),
          ),
          _buildActionButton(
            icon: Icons.forward_rounded,
            label: 'Forward',
            onTap: () => _navigateToCompose('forward'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: AppTheme.primaryColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToCompose(String type) {
    Get.to(() => const ComposeScreen(), arguments: {
      'message': message,
      'type': type,
    });
  }

  void _showDeleteConfirmation(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('Delete Message', style: TextStyle(color: AppTheme.textPrimaryColor)),
        message: Text(
          'Are you sure you want to delete this message?',
          style: TextStyle(color: AppTheme.textSecondaryColor),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              mailController.deleteMails([message], mailbox);
              Get.back(); // Close dialog
              Get.back(); // Go back to inbox
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
