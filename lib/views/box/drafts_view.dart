import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:wahda_bank/features/messaging/presentation/controllers/compose_controller.dart';
import 'package:wahda_bank/features/messaging/presentation/screens/compose/widgets/text_field.dart';
import 'dart:ui';

class WComposeView extends StatelessWidget {
  WComposeView({super.key});

  final controller = Get.find<ComposeController>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // From field with modern styling
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color:
                isDarkMode
                    ? Colors.grey.shade800.withValues(alpha: 0.3)
                    : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isDarkMode ? Colors.black12 : Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextFormField(
                  controller: controller.fromController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: "from".tr,
                    labelStyle: TextStyle(
                      color:
                          isDarkMode
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.person_outline,
                      color:
                          isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ),

        // To field with modern styling
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color:
                isDarkMode
                    ? Colors.grey.shade800.withValues(alpha: 0.3)
                    : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isDarkMode ? Colors.black12 : Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    Obx(
                      () => ToEmailsChipsField(
                        title: "to".tr,
                        emails: controller.toList.toList(),
                        onDelete: (int i) {
                          controller.removeFromToList(i);
                        },
                        onInsert: (MailAddress address) {
                          controller.addTo(address);
                        },
                        ccBccWidget: IconButton(
                          onPressed: () {
                            controller.isCcAndBccVisible.toggle();
                          },
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              controller.isCcAndBccVisible()
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              key: ValueKey(controller.isCcAndBccVisible()),
                              color:
                                  isDarkMode
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700,
                            ),
                          ),
                          tooltip:
                              controller.isCcAndBccVisible()
                                  ? "Hide CC/BCC"
                                  : "Show CC/BCC",
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // CC/BCC fields with animation
        Obx(
          () => AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child:
                controller.isCcAndBccVisible()
                    ? Column(
                      children: [
                        // CC Field
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color:
                                isDarkMode
                                    ? Colors.grey.shade800.withValues(
                                      alpha: 0.3,
                                    )
                                    : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    isDarkMode
                                        ? Colors.black12
                                        : Colors.grey.shade200,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: ToEmailsChipsField(
                                  title: "CC".tr,
                                  emails: controller.cclist.toList(),
                                  onDelete: (int i) {
                                    controller.removeFromCcList(i);
                                  },
                                  onInsert: (MailAddress address) {
                                    controller.addToCC(address);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),

                        // BCC Field
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color:
                                isDarkMode
                                    ? Colors.grey.shade800.withValues(
                                      alpha: 0.3,
                                    )
                                    : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    isDarkMode
                                        ? Colors.black12
                                        : Colors.grey.shade200,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: ToEmailsChipsField(
                                  title: "bcc".tr,
                                  emails: controller.bcclist.toList(),
                                  onDelete: (int i) {
                                    controller.removeFromBccList(i);
                                  },
                                  onInsert: (MailAddress add) {
                                    controller.addToBcc(add);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                    : const SizedBox.shrink(),
          ),
        ),

        // Subject field with modern styling
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color:
                isDarkMode
                    ? Colors.grey.shade800.withValues(alpha: 0.3)
                    : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isDarkMode ? Colors.black12 : Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: TextFormField(
                  controller: controller.subjectController,
                  decoration: InputDecoration(
                    labelText: "subject".tr,
                    labelStyle: TextStyle(
                      color:
                          isDarkMode
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    prefixIcon: Icon(
                      Icons.subject,
                      color:
                          isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Attachments section with modern styling
        Obx(
          () =>
              controller.attachments.isNotEmpty
                  ? Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color:
                          isDarkMode
                              ? Colors.grey.shade800.withValues(alpha: 0.3)
                              : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color:
                              isDarkMode
                                  ? Colors.black12
                                  : Colors.grey.shade200,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                top: 12,
                                bottom: 4,
                              ),
                              child: Text(
                                "attachments".tr,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDarkMode
                                          ? Colors.grey.shade300
                                          : Colors.grey.shade700,
                                ),
                              ),
                            ),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: controller.attachments.length,
                              itemBuilder: (context, index) {
                                final fileName =
                                    controller.attachments[index].path
                                        .split('/')
                                        .last;
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    _getFileIcon(fileName),
                                    color:
                                        isDarkMode
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade700,
                                  ),
                                  title: Text(
                                    fileName,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color:
                                          isDarkMode
                                              ? Colors.white
                                              : Colors.black87,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: Icon(
                                      Icons.close_rounded,
                                      color:
                                          isDarkMode
                                              ? Colors.grey.shade400
                                              : Colors.grey.shade700,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      controller.attachments.removeAt(index);
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  : const SizedBox.shrink(),
        ),

        // Email body editor with modern styling
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color:
                isDarkMode
                    ? Colors.grey.shade800.withValues(alpha: 0.3)
                    : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isDarkMode ? Colors.black12 : Colors.grey.shade200,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Obx(
                  () => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child:
                        controller.isHtml.isTrue
                            ? HtmlEditor(
                              key: const ValueKey('html-editor'),
                              controller: controller.htmlController,
                              htmlToolbarOptions: const HtmlToolbarOptions(
                                renderSeparatorWidget: true,
                                defaultToolbarButtons: [
                                  FontButtons(),
                                  ColorButtons(),
                                  ListButtons(),
                                  ParagraphButtons(
                                    caseConverter: false,
                                    textDirection: true,
                                  ),
                                ],
                                toolbarPosition: ToolbarPosition.aboveEditor,
                                toolbarType: ToolbarType.nativeScrollable,
                              ),
                              htmlEditorOptions: HtmlEditorOptions(
                                hint: "Your message here...",
                                initialText: controller.bodyPart,
                                shouldEnsureVisible: true,
                                darkMode: isDarkMode,
                              ),
                              otherOptions: const OtherOptions(
                                height: 400,
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                ),
                              ),
                            )
                            : Padding(
                              key: const ValueKey('plain-text-editor'),
                              padding: const EdgeInsets.all(8.0),
                              child: TextFormField(
                                controller: controller.plainTextController,
                                maxLines: 15,
                                keyboardType: TextInputType.multiline,
                                decoration: InputDecoration(
                                  hintText: "Your message here...",
                                  hintStyle: TextStyle(
                                    color:
                                        isDarkMode
                                            ? Colors.grey.shade400
                                            : Colors.grey.shade500,
                                  ),
                                  border: InputBorder.none,
                                ),
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      isDarkMode
                                          ? Colors.white
                                          : Colors.black87,
                                ),
                              ),
                            ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Format toggle button
        Align(
          alignment: Alignment.centerRight,
          child: Obx(
            () => TextButton.icon(
              onPressed: controller.togglePlainHtml,
              icon: Icon(
                controller.isHtml.isTrue ? Icons.text_fields : Icons.code,
                size: 18,
              ),
              label: Text(
                controller.isHtml.isTrue ? "plain_text".tr : "rich_text".tr,
                style: const TextStyle(fontSize: 12),
              ),
              style: TextButton.styleFrom(
                foregroundColor:
                    isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),

        // Signature with modern styling
        if (controller.signature.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  isDarkMode
                      ? Colors.grey.shade800.withValues(alpha: 0.2)
                      : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    "signature".tr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                    ),
                  ),
                ),
                HtmlWidget(
                  controller.signature,
                  textStyle: TextStyle(
                    color:
                        isDarkMode
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // Helper method to determine file icon based on extension
  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return Icons.image_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_outlined;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_outlined;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}
