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
    return Obx(() {
      final selectedCount = selectionController.selectedCount;
      
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
          left: 16,
          right: 16,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Selection count header
              Row(
                children: [
                  Text(
                    '$selectedCount selected',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryColor,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => selectionController.clear(),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Actions Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: 'delete'.tr,
                    onTap: () => _showDeleteConfirmation(context),
                    destructive: true,
                  ),
                  _buildActionButton(
                    icon: Icons.mark_email_unread_rounded,
                    label: 'Unread',
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
                    icon: Icons.mark_email_read_rounded,
                    label: 'Read',
                    onTap: () async {
                      await mailController.markAsReadUnread(
                        selectionController.selected,
                        box,
                      );
                      selectionController.clear();
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.flag_outlined,
                    label: 'Flag',
                    onTap: () async {
                      // Flag functionality - implement if needed
                      selectionController.clear();
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.drive_file_move_outline,
                    label: 'Move',
                    onTap: () => _showMoveActionSheet(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: destructive
                  ? Colors.red.withValues(alpha : 0.1)
                  : AppTheme.primaryColor.withValues(alpha : 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: destructive ? Colors.red : AppTheme.primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: destructive ? Colors.red : AppTheme.textPrimaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(
          'are_you_u_wtd'.tr,
          style: const TextStyle(color: AppTheme.textPrimaryColor),
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