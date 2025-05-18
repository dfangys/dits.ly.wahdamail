import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

class ViewMessageBottomNav extends StatelessWidget {
  const ViewMessageBottomNav({
    super.key,
    required this.mailbox,
    required this.message,
  });

  final Mailbox mailbox;
  final MimeMessage message;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MailBoxController>();
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
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
              icon: Icons.archive_outlined,
              label: 'Archive',
              onTap: () {
                // Find archive mailbox
                final archiveBox = controller.mailboxes.firstWhereOrNull(
                      (box) => box.name.toLowerCase() == 'archive',
                );

                if (archiveBox != null) {
                  controller.moveMails(
                    [message],
                    mailbox,
                    archiveBox,
                  );
                  Get.back();
                } else {
                  // Show error or create archive folder
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Archive folder not found'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppTheme.errorColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                }
              },
            ),

            _buildActionButton(
              context: context,
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              onTap: () {
                // Show delete confirmation
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
                          controller.deleteMessages([message], mailbox);
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
              },
              destructive: true,
            ),

            _buildActionButton(
              context: context,
              icon: Icons.mark_email_unread_rounded,
              label: 'Unread',
              onTap: () {
                controller.markAsUnread([message], mailbox);
                Get.back();
              },
            ),

            _buildActionButton(
              context: context,
              icon: Icons.forward_rounded,
              label: 'Forward',
              onTap: () {
                Get.toNamed('/compose', arguments: {
                  'replyTo': message,
                  'action': 'forward',
                });
              },
            ),

            _buildActionButton(
              context: context,
              icon: Icons.reply_all_rounded,
              label: 'Reply All',
              onTap: () {
                Get.toNamed('/compose', arguments: {
                  'replyTo': message,
                  'action': 'replyAll',
                });
              },
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
                    ? Colors.red.withOpacity(0.1)
                    : AppTheme.primaryColor.withOpacity(0.1),
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
}
