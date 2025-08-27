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
    return PopScope(
      canPop: controller.canPop(),
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final navigator = Navigator.of(context);
          // If there are unsaved changes, show confirmation dialog
          if (controller.hasUnsavedChanges) {
            var isConfirmed = await confirmDraft(context);
            if (isConfirmed) {
              await controller.saveAsDraft();
            }
            controller.canPop(true);
            if (mounted) {
              navigator.pop();
            }
          } else {
            controller.canPop(true);
            if (mounted) {
              navigator.pop();
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'compose_email'.tr,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          actions: [
            // Draft status indicator
            Obx(() => controller.draftStatus.isNotEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  controller.draftStatus,
                  style: TextStyle(
                    fontSize: 12,
                    color: controller.draftStatus == 'draft_saved'.tr
                        ? Colors.green
                        : controller.draftStatus == 'saving_draft'.tr
                        ? Colors.orange
                        : controller.draftStatus == 'unsaved_changes'.tr
                        ? Colors.red
                        : Colors.grey,
                  ),
                ),
              ),
            )
                : const SizedBox.shrink()),
            IconButton(
              onPressed: controller.sendEmail,
              icon: const Icon(
                Icons.send_outlined,
                color: AppTheme.primaryColor,
                size: 22,
              ),
            ),
            IconButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.white,
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
                            color: Colors.grey.shade300,
                          ),
                        ),
                        Text(
                          'attach_file'.tr,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.folder_outlined, color: Colors.blue),
                          ),
                          title: Text('from_files'.tr),
                          onTap: () {
                            Get.back();
                            controller.pickFiles();
                          },
                        ),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.photo_outlined, color: Colors.green),
                          ),
                          title: Text('from_gallery'.tr),
                          onTap: () {
                            Get.back();
                            controller.pickImage();
                          },
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ElevatedButton(
                            onPressed: () => Get.back(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              foregroundColor: Colors.black,
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
              },
              icon: const Icon(Icons.attach_file_outlined),
            ),
            IconButton(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.white,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (context) => DraftOptionsSheet(),
                );
              },
              icon: const Icon(Icons.more_vert_outlined),
            ),
          ],
        ),
        body: Stack(
          children: [
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
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            '${'last_saved'.tr}: ${controller.lastSavedTime}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      )
                          : const SizedBox.shrink()),

                      // Compose view
                      WComposeView(),

                      // Auto-save indicator
                      Obx(() => controller.isAutosaving
                          ? Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'autosaving'.tr,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
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

            // Draft options floating button
            Obx(() => controller.showDraftOptions
                ? Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                backgroundColor: AppTheme.primaryColor,
                child: const Icon(Icons.save_outlined),
                onPressed: () {
                  controller.saveAsDraft();
                },
              ),
            )
                : const SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

class DraftOptionsSheet extends StatelessWidget {
  DraftOptionsSheet({super.key});

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
              color: Colors.grey.shade300,
            ),
          ),
          Text(
            'more_options'.tr,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.save_outlined, color: Colors.amber),
            ),
            title: Text('save_as_draft'.tr),
            onTap: () {
              Get.back();
              controller.saveAsDraft();
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.schedule_outlined, color: Colors.indigo),
            ),
            title: Text('schedule_send'.tr),
            onTap: () {
              Get.back();
              _showScheduleDialog(context);
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepPurple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.category_outlined, color: Colors.deepPurple),
            ),
            title: Text('categorize_draft'.tr),
            onTap: () {
              Get.back();
              _showCategoryDialog(context);
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt_long_outlined, color: Colors.purple),
            ),
            title: Text('request_read_receipt'.tr),
            trailing: Obx(() => Switch(
              value: Get.find<SettingController>().readReceipts.value,
              onChanged: (value) {
                Get.find<SettingController>().readReceipts.value = value;
              },
              activeTrackColor: AppTheme.primaryColor,
            )),
            onTap: () {
              Get.find<SettingController>().readReceipts.toggle();
            },
          ),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.text_format, color: Colors.teal),
            ),
            title: Text('convert_to_plain_text'.tr),
            onTap: () {
              Get.back();
              controller.togglePlainHtml();
            },
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: () => Get.back(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade200,
                foregroundColor: Colors.black,
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
                ListTile(
                  title: Text('date'.tr),
                  subtitle: Text(DateFormat('EEE, MMM d, yyyy').format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
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
                ListTile(
                  title: Text('time'.tr),
                  subtitle: Text(selectedTime.format(context)),
                  trailing: const Icon(Icons.access_time),
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
                child: Text('schedule'.tr),
              ),
            ],
          );
        },
      ),
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
                    // ignore: deprecated_member_use
                    groupValue: selectedCategory,
                    // ignore: deprecated_member_use
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
                child: Text('save'.tr),
              ),
            ],
          );
        },
      ),
    );
  }
}
