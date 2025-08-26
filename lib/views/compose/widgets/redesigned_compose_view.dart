import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';
import 'package:wahda_bank/views/compose/widgets/enhanced_text_field.dart';
import 'package:wahda_bank/views/compose/widgets/attachment_section.dart';
import 'package:wahda_bank/views/compose/widgets/compose_toolbar.dart';

/// Redesigned compose view with enhanced UX and modern design
class RedesignedComposeView extends StatelessWidget {
  RedesignedComposeView({super.key});

  final controller = Get.find<ComposeController>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header with visual indicator
          _buildHeader(theme),
          
          // Main content area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  
                  // Last saved time indicator (like original)
                  Obx(() => controller.lastSavedTime.isNotEmpty
                      ? Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_outlined,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${'last_saved'.tr}: ${controller.lastSavedTime}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink()),
                  
                  // From field with enhanced styling
                  _buildFromField(theme),
                  
                  const SizedBox(height: 16),
                  
                  // Recipients section with improved UX
                  _buildRecipientsSection(theme),
                  
                  const SizedBox(height: 16),
                  
                  // Subject field with enhanced design
                  _buildSubjectField(theme),
                  
                  const SizedBox(height: 16),
                  
                  // Attachments section (if any)
                  _buildAttachmentsSection(theme),
                  
                  const SizedBox(height: 16),
                  
                  // Message composition area
                  _buildMessageComposer(theme),
                  
                  const SizedBox(height: 16),
                  
                  // Signature section
                  _buildSignatureSection(theme),
                  
                  // Autosave indicator (like original)
                  Obx(() => controller.isAutosaving
                      ? Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outline.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'autosaving'.tr,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink()),
                  
                  const SizedBox(height: 100), // Bottom padding for FAB
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.edit_outlined,
            color: theme.colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'compose_email'.tr,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
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
                        Icons.circle,
                        size: 8,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'unsaved_changes'.tr,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontSize: 11,
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

  Widget _buildFromField(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.person_outline,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'from'.tr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  controller.fromController.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipientsSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          // To field
          Padding(
            padding: const EdgeInsets.all(16),
            child: Obx(() => EnhancedEmailChipsField(
              title: "to".tr,
              icon: Icons.mail_outline,
              emails: controller.toList.toList(),
              onDelete: (int i) => controller.removeFromToList(i),
              onInsert: (MailAddress address) => controller.addTo(address),
              trailingWidget: _buildCcBccToggle(theme),
            )),
          ),
          
          // CC/BCC fields with smooth animation
          Obx(() => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            height: controller.isCcAndBccVisible() ? null : 0,
            child: controller.isCcAndBccVisible()
                ? Column(
                    children: [
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: EnhancedEmailChipsField(
                          title: "CC".tr,
                          icon: Icons.copy_outlined,
                          emails: controller.cclist.toList(),
                          onDelete: (int i) => controller.removeFromCcList(i),
                          onInsert: (MailAddress address) => controller.addToCC(address),
                        ),
                      ),
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: EnhancedEmailChipsField(
                          title: "bcc".tr,
                          icon: Icons.visibility_off_outlined,
                          emails: controller.bcclist.toList(),
                          onDelete: (int i) => controller.removeFromBccList(i),
                          onInsert: (MailAddress address) => controller.addToBcc(address),
                        ),
                      ),
                    ],
                  )
                : const SizedBox(),
          )),
        ],
      ),
    );
  }

  Widget _buildCcBccToggle(ThemeData theme) {
    return Obx(() => AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: InkWell(
        onTap: () => controller.isCcAndBccVisible.toggle(),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: controller.isCcAndBccVisible()
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : theme.colorScheme.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                controller.isCcAndBccVisible()
                    ? Icons.expand_less
                    : Icons.expand_more,
                size: 16,
                color: controller.isCcAndBccVisible()
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                controller.isCcAndBccVisible() ? 'hide_cc_bcc'.tr : 'cc_bcc'.tr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: controller.isCcAndBccVisible()
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _buildSubjectField(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.subject_outlined,
              color: theme.colorScheme.secondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: controller.subjectController,
              decoration: InputDecoration(
                labelText: "subject".tr,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                labelStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection(ThemeData theme) {
    return Obx(() => controller.attachments.isNotEmpty
        ? Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.attach_file_outlined,
                        color: theme.colorScheme.tertiary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'attachments'.tr,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${controller.attachments.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...controller.attachments.asMap().entries.map((entry) {
                  final index = entry.key;
                  final file = entry.value;
                  return AttachmentTile(
                    file: file,
                    onRemove: () => controller.attachments.removeAt(index),
                  );
                }),
              ],
            ),
          )
        : const SizedBox());
  }

  Widget _buildMessageComposer(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          // Toolbar
          ComposeToolbar(),
          
          const Divider(height: 1),
          
          // Editor area
          Obx(() => AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: controller.isHtml.isTrue
                ? _buildHtmlEditor(theme)
                : _buildPlainTextEditor(theme),
          )),
        ],
      ),
    );
  }

  Widget _buildHtmlEditor(ThemeData theme) {
    return Container(
      key: const ValueKey('html_editor'),
      height: 300,
      child: HtmlEditor(
        controller: controller.htmlController,
        htmlToolbarOptions: const HtmlToolbarOptions(
          renderSeparatorWidget: false,
          toolbarPosition: ToolbarPosition.custom,
          defaultToolbarButtons: [
            FontButtons(),
            ColorButtons(),
            ListButtons(),
            ParagraphButtons(
              caseConverter: false,
              textDirection: true,
            ),
          ],
        ),
        htmlEditorOptions: HtmlEditorOptions(
          hint: "compose_your_message".tr,
          initialText: controller.bodyPart,
          shouldEnsureVisible: true,
        ),
        otherOptions: OtherOptions(
          height: 300,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlainTextEditor(ThemeData theme) {
    return Container(
      key: const ValueKey('plain_editor'),
      padding: const EdgeInsets.all(16),
      child: TextFormField(
        controller: controller.plainTextController,
        maxLines: 12,
        minLines: 12,
        keyboardType: TextInputType.multiline,
        decoration: InputDecoration(
          hintText: "compose_your_message".tr,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        style: theme.textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildSignatureSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.draw_outlined,
                color: theme.colorScheme.onSurfaceVariant,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'signature'.tr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          HtmlWidget(
            controller.signature,
            textStyle: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

