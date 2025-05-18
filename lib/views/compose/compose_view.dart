import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';
import 'package:wahda_bank/views/compose/widgets/text_field.dart';
import 'package:enough_mail/enough_mail.dart';

// This class serves as both ComposeView and ComposeScreen to fix reference issues
class ComposeView extends StatefulWidget {
  final MimeMessage? draftMessage;

  const ComposeView({Key? key, this.draftMessage}) : super(key: key);

  @override
  State<ComposeView> createState() => _ComposeViewState();
}

// ComposeScreen is an alias for ComposeView to fix reference issues
class ComposeScreen extends ComposeView {
  const ComposeScreen({Key? key, MimeMessage? draftMessage})
      : super(key: key, draftMessage: draftMessage);
}

class _ComposeViewState extends State<ComposeView> {
  late final ComposeController controller;
  final HtmlEditorController htmlController = HtmlEditorController();

  @override
  void initState() {
    super.initState();
    controller = Get.put(ComposeController());

    // Load draft if provided
    if (widget.draftMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.loadDraft(widget.draftMessage!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'compose_email'.tr,
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _handleBackPress();
          },
        ),
        actions: [
          // Send button
          Obx(() => controller.isSending.value
              ? Container(
            margin: const EdgeInsets.all(8),
            width: 35,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryColor,
            ),
          )
              : IconButton(
            onPressed: () {
              controller.sendEmail();
            },
            icon: Icon(
              Icons.send_rounded,
              color: AppTheme.primaryColor,
            ),
            tooltip: 'send'.tr,
          )),

          // Save draft button
          Obx(() => controller.isSavingDraft.value
              ? Container(
            margin: const EdgeInsets.all(8),
            width: 35,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryColor,
            ),
          )
              : IconButton(
            onPressed: () {
              controller.saveAsDraft();
            },
            icon: Icon(
              Icons.save_outlined,
              color: AppTheme.primaryColor,
            ),
            tooltip: 'save_draft'.tr,
          )),

          // Attachment button
          IconButton(
            onPressed: () {
              _showAttachmentOptions();
            },
            icon: Icon(
              Icons.attach_file_rounded,
              color: AppTheme.primaryColor,
            ),
            tooltip: 'attach'.tr,
          ),

          // More options
          PopupMenuButton(
            icon: Icon(
              Icons.more_vert,
              color: AppTheme.primaryColor,
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'html',
                child: Row(
                  children: [
                    Obx(() => Icon(
                      controller.isHtml.value
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: AppTheme.primaryColor,
                    )),
                    const SizedBox(width: 8),
                    Text('html_mode'.tr),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'discard',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(width: 8),
                    Text('discard'.tr),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'html') {
                controller.toggleHtmlMode();
              } else if (value == 'discard') {
                _confirmDiscard();
              }
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Obx(
              () => Column(
            children: [
              // Email form
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // From field
                        _buildSectionLabel('from'.tr),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border:
                            Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                AppTheme.primaryColor.withOpacity(0.2),
                                child: Text(
                                  controller.name.isNotEmpty
                                      ? controller.name[0].toUpperCase()
                                      : controller.email[0].toUpperCase(),
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: controller.fromController,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textPrimaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // To field
                        _buildSectionLabel('to'.tr),
                        ToEmailsChipsField(
                          title: 'to'.tr,
                          emails: controller.toList,
                          onInsert: controller.addTo,
                          onDelete: controller.removeFromToList,
                          ccBccWidget: IconButton(
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: AppTheme.primaryColor,
                            ),
                            onPressed: () {
                              controller.showCcBcc();
                            },
                            tooltip: 'cc_bcc'.tr,
                            splashRadius: 20,
                          ),
                        ),

                        // CC and BCC fields
                        if (controller.isCcAndBccVisible.value) ...[
                          const SizedBox(height: 16),
                          _buildSectionLabel('cc'.tr),
                          ToEmailsChipsField(
                            title: 'cc'.tr,
                            emails: controller.cclist,
                            onInsert: controller.addToCC,
                            onDelete: controller.removeFromCcList,
                          ),
                          const SizedBox(height: 16),
                          _buildSectionLabel('bcc'.tr),
                          ToEmailsChipsField(
                            title: 'bcc'.tr,
                            emails: controller.bcclist,
                            onInsert: controller.addToBcc,
                            onDelete: controller.removeFromBccList,
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Subject field
                        _buildSectionLabel('subject'.tr),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border:
                            Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: TextField(
                            controller: controller.subjectController,
                            decoration: InputDecoration(
                              hintText: 'subject'.tr,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Attachments
                        if (controller.attachments.isNotEmpty) ...[
                          _buildSectionLabel('attachments'.tr),
                          Container(
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.grey.withOpacity(0.2)),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: controller.attachments.length,
                              separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final file = controller.attachments[index];
                                final fileName = file.path.split('/').last;
                                final fileSize =
                                _formatFileSize(file.lengthSync());

                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    _getFileIcon(fileName),
                                    color: AppTheme.primaryColor,
                                  ),
                                  title: Text(
                                    fileName,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                  subtitle: Text(
                                    fileSize,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      size: 18,
                                      color: Colors.red.shade400,
                                    ),
                                    onPressed: () =>
                                        controller.deleteAttachment(index),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Message body
                        _buildSectionLabel('message'.tr),
                        Container(
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border:
                            Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: controller.isHtml.value
                              ? HtmlEditor(
                            controller: controller.htmlController,
                            htmlEditorOptions: HtmlEditorOptions(
                              hint: 'compose_message'.tr,
                              initialText: controller.bodyPart,
                            ),
                            htmlToolbarOptions: const HtmlToolbarOptions(
                              toolbarPosition: ToolbarPosition.aboveEditor,
                              toolbarType: ToolbarType.nativeScrollable,
                            ),
                            callbacks: Callbacks(
                              onInit: () {
                                controller.htmlController.setFocus();
                              },
                              onChangeContent: (content) {
                                controller.htmlBody = content ?? '';
                              },
                            ),
                          )
                              : TextField(
                            controller: controller.plainTextController,
                            maxLines: 10,
                            decoration: InputDecoration(
                              hintText: 'compose_message'.tr,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                        ),

                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          controller.sendEmail();
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.send),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondaryColor,
        ),
      ),
    );
  }

  void _handleBackPress() {
    if (controller.canDiscard()) {
      _confirmDiscard();
    } else {
      Get.back();
    }
  }

  void _confirmDiscard() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('discard_draft'.tr),
        content: Text('discard_draft_message'.tr),
        actions: [
          TextButton(
            onPressed: () {
              Get.back();
            },
            child: Text(
              'cancel'.tr,
              style: TextStyle(color: AppTheme.textSecondaryColor),
            ),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              controller.saveAsDraft();
              Get.back();
            },
            child: Text(
              'save_draft'.tr,
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              Get.back();
            },
            child: Text(
              'discard'.tr,
              style: TextStyle(color: Colors.red.shade400),
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'add_attachment'.tr,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.photo_library_rounded,
                  label: 'gallery'.tr,
                  onTap: () {
                    Get.back();
                    controller.pickImage();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'camera'.tr,
                  onTap: () {
                    Get.back();
                    controller.takePhoto();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'document'.tr,
                  onTap: () {
                    Get.back();
                    controller.pickFiles();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppTheme.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textPrimaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
      return Icons.image;
    } else if (extension == 'pdf') {
      return Icons.picture_as_pdf;
    } else if (['doc', 'docx'].contains(extension)) {
      return Icons.description;
    } else if (['xls', 'xlsx', 'csv'].contains(extension)) {
      return Icons.table_chart;
    } else if (['ppt', 'pptx'].contains(extension)) {
      return Icons.slideshow;
    } else if (['zip', 'rar', '7z'].contains(extension)) {
      return Icons.folder_zip;
    } else if (['mp3', 'wav', 'ogg'].contains(extension)) {
      return Icons.audio_file;
    } else if (['mp4', 'mov', 'avi'].contains(extension)) {
      return Icons.video_file;
    }

    return Icons.insert_drive_file;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
