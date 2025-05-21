import 'package:collection/collection.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/app/controllers/selection_controller.dart';
import 'package:wahda_bank/utills/extensions.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

class SelectionBottomNav extends StatelessWidget {
  SelectionBottomNav({super.key, required this.box});

  final Mailbox box;

  final selectionController = Get.find<SelectionController>();
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
              label: 'delete'.tr,
              destructive: true,
              onTap: () => _showDeleteConfirmation(context),
            ),
            _buildActionButton(
              context: context,
              icon: Icons.mark_email_unread_rounded,
              label: 'Mark Unread',
              onTap: () async {
                mailController.markAsReadUnread(
                  selectionController.selected,
                  box,
                  false,
                );
                selectionController.clear();
              },
            ),
            _buildActionButton(
              context: context,
              icon: Icons.mark_email_read_rounded,
              label: 'Mark Read',
              onTap: () async {
                await mailController.markAsReadUnread(
                  selectionController.selected,
                  box,
                );
                selectionController.clear();
              },
            ),
            _buildActionButton(
              context: context,
              icon: Icons.drive_file_move_outline,
              label: 'Move',
              onTap: () => _showMoveActionSheet(context),
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

  void _showDeleteConfirmation(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(
          'are_you_u_wtd'.tr,
          style: TextStyle(color: AppTheme.textPrimaryColor),
        ),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Get.back();
              await mailController.deleteMails(
                selectionController.selected,
                box,
              );
              selectionController.clear();
            },
            isDestructiveAction: true,
            child: Text('delete'.tr),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Get.back(),
          child: Text('cancel'.tr),
        ),
      ),
    );
  }

  void _showMoveActionSheet(BuildContext context) {
    final otherBoxes = mailController.mailboxes
        .whereNot((e) => e == box)
        .toList();

    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text('move_to'.tr),
        actions: [
          for (var item in otherBoxes)
            CupertinoActionSheetAction(
              onPressed: () async {
                Get.back();
                await mailController.moveMails(
                  selectionController.selected,
                  box,
                  item,
                );
                selectionController.clear();
              },
              child: Text(item.name.ucFirst()),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Get.back(),
          child: Text('cancel'.tr),
        ),
      ),
    );
  }
}