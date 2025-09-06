import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:wahda_bank/features/messaging/presentation/compose_view_model.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';

/// Modern draft options sheet with enhanced design and all features
class ModernDraftOptionsSheet extends StatelessWidget {
  ModernDraftOptionsSheet({super.key});

final controller = Get.find<ComposeViewModel>();
  final settingsController = Get.find<SettingController>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.more_horiz_rounded,
                        color: theme.colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'more_options'.tr,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Options list
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Save as draft
                    _buildOptionTile(
                      context,
                      icon: Icons.save_outlined,
                      iconColor: Colors.amber,
                      title: 'save_as_draft'.tr,
                      subtitle: 'save_current_progress'.tr,
                      onTap: () {
                        Get.back();
                        controller.saveAsDraft();
                      },
                    ),

                    const SizedBox(height: 8),

                    // Discard draft (delete from server if applicable)
                    _buildOptionTile(
                      context,
                      icon: Icons.delete_outline,
                      iconColor: Colors.red,
                      title: 'discard_draft'.tr,
                      subtitle: 'discard_draft_from_server'.tr,
                      onTap: () {
                        Get.back();
                        controller.discardCurrentDraft();
                      },
                    ),

                    const SizedBox(height: 8),

                    // Manage pending draft attachments
                    _buildOptionTile(
                      context,
                      icon: Icons.cloud_download_outlined,
                      iconColor: Colors.blueGrey,
                      title: 'manage_draft_attachments'.tr,
                      subtitle: 'reattach_or_view_draft_attachments'.tr,
                      onTap: () {
                        Get.back();
                        // Scroll to attachments section can be implemented if needed
                      },
                    ),

                    const SizedBox(height: 8),

                    // Schedule send
                    _buildOptionTile(
                      context,
                      icon: Icons.schedule_outlined,
                      iconColor: Colors.indigo,
                      title: 'schedule_send'.tr,
                      subtitle: 'send_at_specific_time'.tr,
                      onTap: () {
                        Get.back();
                        _showScheduleDialog(context);
                      },
                    ),

                    const SizedBox(height: 8),

                    // Categorize draft
                    _buildOptionTile(
                      context,
                      icon: Icons.category_outlined,
                      iconColor: Colors.deepPurple,
                      title: 'categorize_draft'.tr,
                      subtitle: 'organize_your_drafts'.tr,
                      onTap: () {
                        Get.back();
                        _showCategoryDialog(context);
                      },
                    ),

                    const SizedBox(height: 8),

                    // Read receipt toggle
                    _buildToggleTile(
                      context,
                      icon: Icons.receipt_long_outlined,
                      iconColor: Colors.purple,
                      title: 'request_read_receipt'.tr,
                      subtitle: 'know_when_email_is_read'.tr,
                      rxValue: settingsController.readReceipts,
                      onChanged: (value) {
                        settingsController.readReceipts.value = value;
                      },
                    ),

                    const SizedBox(height: 8),

                    // Convert to plain text
                    _buildOptionTile(
                      context,
                      icon: Icons.text_format_outlined,
                      iconColor: Colors.teal,
                      title: 'convert_to_plain_text'.tr,
                      subtitle:
                          controller.isHtml.value
                              ? 'switch_to_plain_text'.tr
                              : 'switch_to_rich_text'.tr,
                      onTap: () {
                        Get.back();
                        controller.togglePlainHtml();
                      },
                    ),

                    const SizedBox(height: 8),

                    // Priority setting
                    _buildOptionTile(
                      context,
                      icon: Icons.flag_outlined,
                      iconColor: _getPriorityColor(),
                      title: 'set_priority'.tr,
                      subtitle: _getPriorityText(),
                      onTap: () {
                        Get.back();
                        _showPriorityDialog(context);
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Close button
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () => Get.back(),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'close'.tr,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required RxBool rxValue,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Obx(
            () => Switch(
              value: rxValue.value,
              onChanged: onChanged,
              activeTrackColor: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor() {
    switch (controller.priority.value) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getPriorityText() {
    switch (controller.priority.value) {
      case 1:
        return 'low_priority'.tr;
      case 2:
        return 'high_priority'.tr;
      case 3:
        return 'urgent_priority'.tr;
      default:
        return 'normal_priority'.tr;
    }
  }

  void _showScheduleDialog(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    DateTime selectedDate = now.add(const Duration(days: 1));
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.schedule_outlined,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('schedule_send'.tr),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'select_date_time'.tr,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Date picker
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: now,
                            lastDate: now.add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() {
                              selectedDate = date;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'date'.tr,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    DateFormat(
                                      'EEE, MMM d, yyyy',
                                    ).format(selectedDate),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Time picker
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (time != null) {
                            setState(() {
                              selectedTime = time;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time_outlined,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'time'.tr,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    selectedTime.format(context),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text('cancel'.tr),
                  ),
                  FilledButton(
                    onPressed: () {
                      final scheduledDateTime = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );

                      if (scheduledDateTime.isBefore(now)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('schedule_time_past'.tr),
                            backgroundColor: theme.colorScheme.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                        return;
                      }

                      Get.back();
                      controller.scheduleDraft(scheduledDateTime);
                    },
                    child: Text('schedule'.tr),
                  ),
                ],
              );
            },
          ),
    );
  }

  void _showCategoryDialog(BuildContext context) {
    final theme = Theme.of(context);
    final categories = [
      {'key': 'work', 'icon': Icons.work_outline, 'color': Colors.blue},
      {'key': 'personal', 'icon': Icons.person_outline, 'color': Colors.green},
      {'key': 'important', 'icon': Icons.priority_high, 'color': Colors.red},
      {
        'key': 'follow_up',
        'icon': Icons.follow_the_signs,
        'color': Colors.orange,
      },
      {'key': 'later', 'icon': Icons.schedule, 'color': Colors.purple},
      {'key': 'custom', 'icon': Icons.edit_outlined, 'color': Colors.grey},
    ];

    String selectedCategory = 'default';
    String customCategory = '';

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.category_outlined,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('categorize_draft'.tr),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'select_category'.tr,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...categories.map(
                      (category) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                selectedCategory = category['key'] as String;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color:
                                    selectedCategory == category['key']
                                        ? theme.colorScheme.primaryContainer
                                        : theme
                                            .colorScheme
                                            .surfaceContainerHighest
                                            .withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      selectedCategory == category['key']
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.outline
                                              .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    category['icon'] as IconData,
                                    color: category['color'] as Color,
                                  ),
                                  const SizedBox(width: 12),
                                  Text((category['key'] as String).tr),
                                  const Spacer(),
                                  if (selectedCategory == category['key'])
                                    Icon(
                                      Icons.check_circle,
                                      color: theme.colorScheme.primary,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (selectedCategory == 'custom') ...[
                      const SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'custom_category'.tr,
                          hintText: 'enter_category_name'.tr,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (value) {
                          customCategory = value;
                        },
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Get.back(),
                    child: Text('cancel'.tr),
                  ),
                  FilledButton(
                    onPressed: () {
                      final category =
                          selectedCategory == 'custom'
                              ? customCategory
                              : selectedCategory;
                      if (category.isNotEmpty) {
                        Get.back();
                        controller.categorizeDraft(category);
                      }
                    },
                    child: Text('save'.tr),
                  ),
                ],
              );
            },
          ),
    );
  }

  void _showPriorityDialog(BuildContext context) {
    final theme = Theme.of(context);
    final priorities = [
      {
        'level': 0,
        'label': 'normal'.tr,
        'color': Colors.grey,
        'icon': Icons.remove,
      },
      {
        'level': 1,
        'label': 'low'.tr,
        'color': Colors.blue,
        'icon': Icons.keyboard_arrow_down,
      },
      {
        'level': 2,
        'label': 'high'.tr,
        'color': Colors.orange,
        'icon': Icons.keyboard_arrow_up,
      },
      {
        'level': 3,
        'label': 'urgent'.tr,
        'color': Colors.red,
        'icon': Icons.priority_high,
      },
    ];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.flag_outlined, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                Text('set_priority'.tr),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  priorities
                      .map(
                        (priority) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Obx(
                            () => Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  controller.priority.value =
                                      priority['level'] as int;
                                  Get.back();
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        controller.priority.value ==
                                                priority['level']
                                            ? theme.colorScheme.primaryContainer
                                            : theme
                                                .colorScheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          controller.priority.value ==
                                                  priority['level']
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.outline
                                                  .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        priority['icon'] as IconData,
                                        color: priority['color'] as Color,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(priority['label'] as String),
                                      const Spacer(),
                                      if (controller.priority.value ==
                                          priority['level'])
                                        Icon(
                                          Icons.check_circle,
                                          color: theme.colorScheme.primary,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
            actions: [
              TextButton(onPressed: () => Get.back(), child: Text('close'.tr)),
            ],
          ),
    );
  }
}
