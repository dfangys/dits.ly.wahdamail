import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';
import 'package:wahda_bank/views/compose/widgets/compose_view.dart';
import 'package:intl/intl.dart';

import '../../utills/funtions.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final composeFormKey = GlobalKey<FormState>();
  final controller = Get.put(ComposeController());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (Get.locale != null && Get.locale!.languageCode == 'ar') {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: controller.canPop(),
      onPopInvoked: (didPop) async {
        if (!didPop) {
          // If there are unsaved changes, show confirmation dialog
          if (controller.hasUnsavedChanges) {
            var isConfirmed = await confirmDraft(context);
            if (isConfirmed) {
              await controller.saveDraft();
            }
            controller.canPop(true);
            if (mounted) {
              Navigator.pop(context);
            }
          } else {
            controller.canPop(true);
            if (mounted) {
              Navigator.pop(context);
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor: isDarkMode ? Color(0xFF121212) : Colors.grey.shade50,
        appBar: _buildAppBar(context, isDarkMode),
        body: _buildBody(context, isDarkMode),
        floatingActionButton: _buildFloatingActionButton(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDarkMode) {
    return AppBar(
      elevation: 0,
      backgroundColor: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'back'.tr,
      ),
      title: Text(
        'compose_email'.tr,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        // Draft status indicator with animation
        Obx(() => controller.draftStatus.isNotEmpty
            ? AnimatedContainer(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(horizontal: 8.0),
          decoration: BoxDecoration(
            color: _getDraftStatusColor(controller.draftStatus).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          margin: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Center(
            child: Text(
              controller.draftStatus,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _getDraftStatusColor(controller.draftStatus),
              ),
            ),
          ),
        )
            : const SizedBox.shrink()),

        // Send button
        Tooltip(
          message: 'send'.tr,
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              onPressed: controller.sendEmail,
              icon: Icon(
                Icons.send_outlined,
                color: Colors.white,
                size: 20,
              ),
              splashRadius: 24,
            ),
          ),
        ),

        // Attachment button
        Tooltip(
          message: 'attach'.tr,
          child: IconButton(
            onPressed: () {
              _showAttachmentOptions(context, isDarkMode);
            },
            icon: const Icon(Icons.attach_file_outlined, size: 22),
            splashRadius: 24,
          ),
        ),

        // More options button
        Tooltip(
          message: 'more_options'.tr,
          child: IconButton(
            onPressed: () {
              _showMoreOptions(context, isDarkMode);
            },
            icon: const Icon(Icons.more_vert_outlined, size: 22),
            splashRadius: 24,
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, bool isDarkMode) {
    return Stack(
      children: [
        // Main content
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Form(
            key: composeFormKey,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                children: [
                  // Last saved time indicator
                  Obx(() => controller.lastSavedTime.isNotEmpty
                      ? Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.grey.shade800.withOpacity(0.5)
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade700,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${'last_saved'.tr}: ${controller.lastSavedTime}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      : const SizedBox.shrink()),

                  // Compose view
                  WComposeView(),

                  // Auto-save indicator
                  Obx(() => controller.isAutosaving
                      ? Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    margin: EdgeInsets.only(top: 16),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'autosaving'.tr,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                      : const SizedBox.shrink()),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return Obx(() => controller.showDraftOptions
        ? FloatingActionButton.extended(
      backgroundColor: AppTheme.primaryColor,
      icon: const Icon(Icons.save_outlined),
      label: Text('save_draft'.tr),
      onPressed: () {
        controller.saveDraft();
      },
      elevation: 4,
    )
        : const SizedBox.shrink());
  }

  void _showAttachmentOptions(BuildContext context, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
              ),
            ),
            Text(
              'attach_file'.tr,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildAttachmentOption(
              context,
              icon: Icons.folder_outlined,
              color: Colors.blue,
              title: 'from_files'.tr,
              onTap: () {
                Get.back();
                controller.addAttachment();
              },
              isDarkMode: isDarkMode,
            ),
            _buildAttachmentOption(
              context,
              icon: Icons.photo_outlined,
              color: Colors.green,
              title: 'from_gallery'.tr,
              onTap: () {
                Get.back();
                controller.addImageFromGallery();
              },
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                  foregroundColor: isDarkMode ? Colors.white : Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('cancel'.tr),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(
      BuildContext context, {
        required IconData icon,
        required Color color,
        required String title,
        required VoidCallback onTap,
        required bool isDarkMode,
      }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDarkMode ? color.withOpacity(0.2) : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  void _showMoreOptions(BuildContext context, bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraftOptionsSheet(isDarkMode: isDarkMode),
    );
  }

  Color _getDraftStatusColor(String status) {
    if (status == 'draft_saved'.tr) {
      return Colors.green;
    } else if (status == 'saving_draft'.tr) {
      return Colors.orange;
    } else if (status == 'unsaved_changes'.tr) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }
}

class DraftOptionsSheet extends StatelessWidget {
  final bool isDarkMode;

  DraftOptionsSheet({
    Key? key,
    required this.isDarkMode,
  }) : super(key: key);

  final controller = Get.find<ComposeController>();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
          ),
          Text(
            'more_options'.tr,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildOptionTile(
            context,
            icon: Icons.save_outlined,
            color: Colors.amber,
            title: 'save_as_draft'.tr,
            onTap: () {
              Get.back();
              controller.saveDraft();
            },
          ),
          _buildOptionTile(
            context,
            icon: Icons.schedule_outlined,
            color: Colors.indigo,
            title: 'schedule_send'.tr,
            onTap: () {
              Get.back();
              _showScheduleDialog(context);
            },
          ),
          _buildOptionTile(
            context,
            icon: Icons.category_outlined,
            color: Colors.deepPurple,
            title: 'categorize_draft'.tr,
            onTap: () {
              Get.back();
              _showCategoryDialog(context);
            },
          ),
          _buildSwitchTile(
            context,
            icon: Icons.receipt_long_outlined,
            color: Colors.purple,
            title: 'request_read_receipt'.tr,
            value: Get.find<SettingController>().readReceipts.value,
            onChanged: (value) {
              Get.find<SettingController>().readReceipts.value = value;
            },
          ),
          _buildOptionTile(
            context,
            icon: Icons.text_format,
            color: Colors.teal,
            title: 'convert_to_plain_text'.tr,
            onTap: () {
              Get.back();
              controller.toggleHtmlMode();
            },
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: () => Get.back(),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                foregroundColor: isDarkMode ? Colors.white : Colors.black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('cancel'.tr),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile(
      BuildContext context, {
        required IconData icon,
        required Color color,
        required String title,
        required VoidCallback onTap,
      }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDarkMode ? color.withOpacity(0.2) : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildSwitchTile(
      BuildContext context, {
        required IconData icon,
        required Color color,
        required String title,
        required bool value,
        required ValueChanged<bool> onChanged,
      }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDarkMode ? color.withOpacity(0.2) : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      trailing: Obx(() => Switch(
        value: Get.find<SettingController>().readReceipts.value,
        onChanged: onChanged,
        activeColor: AppTheme.primaryColor,
      )),
      onTap: () {
        Get.find<SettingController>().readReceipts.toggle();
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  void _showScheduleDialog(BuildContext context) {
    final now = DateTime.now();
    DateTime selectedDate = now.add(const Duration(days: 1));
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('schedule_send'.tr),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('select_date_time'.tr),
                const SizedBox(height: 16),
                _buildDateTimeTile(
                  context,
                  title: 'date'.tr,
                  subtitle: DateFormat('EEE, MMM d, yyyy').format(selectedDate),
                  icon: Icons.calendar_today,
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
                ),
                _buildDateTimeTile(
                  context,
                  title: 'time'.tr,
                  subtitle: selectedTime.format(context),
                  icon: Icons.access_time,
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
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('cancel'.tr),
              ),
              ElevatedButton(
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
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Get.back();
                  controller.scheduleDraft(scheduledDateTime);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text('schedule'.tr),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateTimeTile(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required VoidCallback onTap,
      }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Icon(icon, color: AppTheme.primaryColor),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  void _showCategoryDialog(BuildContext context) {
    final categories = [
      'work',
      'personal',
      'important',
      'follow_up',
      'later',
      'custom',
    ];

    String selectedCategory = 'default';
    String customCategory = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('categorize_draft'.tr),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('select_category'.tr),
                const SizedBox(height: 16),
                ...categories.map((category) => RadioListTile<String>(
                  title: Text(category.tr),
                  value: category,
                  groupValue: selectedCategory,
                  activeColor: AppTheme.primaryColor,
                  onChanged: (value) {
                    setState(() {
                      selectedCategory = value!;
                    });
                  },
                )),
                if (selectedCategory == 'custom')
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'custom_category'.tr,
                      hintText: 'enter_category_name'.tr,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: AppTheme.primaryColor),
                      ),
                    ),
                    onChanged: (value) {
                      customCategory = value;
                    },
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('cancel'.tr),
              ),
              ElevatedButton(
                onPressed: () {
                  final category = selectedCategory == 'custom' ? customCategory : selectedCategory;
                  if (category.isNotEmpty) {
                    Get.back();
                    controller.categorizeDraft(category);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: Text('save'.tr),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }
}
