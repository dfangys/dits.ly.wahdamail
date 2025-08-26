import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';

/// Enhanced compose toolbar with improved design and functionality
class ComposeToolbar extends StatelessWidget {
  ComposeToolbar({super.key});

  final controller = Get.find<ComposeController>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Format toggle
          Obx(() => _buildToolbarButton(
            context,
            icon: controller.isHtml.isTrue ? Icons.code_off : Icons.code,
            label: controller.isHtml.isTrue ? 'plain_text'.tr : 'rich_text'.tr,
            onTap: () => controller.togglePlainHtml(),
            isActive: controller.isHtml.isTrue,
          )),
          
          const SizedBox(width: 8),
          
          // Attachment button
          _buildToolbarButton(
            context,
            icon: Icons.attach_file_outlined,
            label: 'attach'.tr,
            onTap: () => _showAttachmentOptions(context),
          ),
          
          const SizedBox(width: 8),
          
          // Priority button
          Obx(() => _buildToolbarButton(
            context,
            icon: Icons.flag_outlined,
            label: 'priority'.tr,
            onTap: () => _showPriorityOptions(context),
            isActive: controller.priority.value > 0,
          )),
          
          const Spacer(),
          
          // Draft indicator
          Obx(() => controller.hasUnsavedChanges
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 12,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'draft'.tr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox()),
        ],
      ),
    );
  }

  Widget _buildToolbarButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.colorScheme.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentOptions(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'add_attachment'.tr,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  context,
                  icon: Icons.photo_library_outlined,
                  label: 'photos'.tr,
                  onTap: () {
                    Navigator.pop(context);
                    controller.pickImage();
                  },
                ),
                _buildAttachmentOption(
                  context,
                  icon: Icons.insert_drive_file_outlined,
                  label: 'files'.tr,
                  onTap: () {
                    Navigator.pop(context);
                    controller.pickFiles();
                  },
                ),
                _buildAttachmentOption(
                  context,
                  icon: Icons.camera_alt_outlined,
                  label: 'camera'.tr,
                  onTap: () {
                    Navigator.pop(context);
                    // Add camera functionality
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPriorityOptions(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'set_priority'.tr,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            ...List.generate(4, (index) {
              final priorities = [
                {'level': 0, 'label': 'normal'.tr, 'color': Colors.grey},
                {'level': 1, 'label': 'low'.tr, 'color': Colors.blue},
                {'level': 2, 'label': 'high'.tr, 'color': Colors.orange},
                {'level': 3, 'label': 'urgent'.tr, 'color': Colors.red},
              ];
              
              final priority = priorities[index];
              
              return Obx(() => ListTile(
                leading: Icon(
                  Icons.flag,
                  color: priority['color'] as Color,
                ),
                title: Text(priority['label'] as String),
                trailing: controller.priority.value == priority['level']
                    ? Icon(
                        Icons.check_circle,
                        color: theme.colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  controller.priority.value = priority['level'] as int;
                  Navigator.pop(context);
                },
              ));
            }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

