import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/features/messaging/presentation/controllers/compose_controller.dart';
import 'package:wahda_bank/features/messaging/presentation/screens/compose/widgets/enhanced_text_field.dart';
import 'package:wahda_bank/features/messaging/presentation/screens/compose/widgets/attachment_section.dart';
import 'package:wahda_bank/features/messaging/presentation/screens/compose/compose_toolbar.dart';
import 'package:wahda_bank/features/messaging/presentation/screens/compose/widgets/pending_draft_attachment_tile.dart';

/// Redesigned compose view with enhanced UX and modern design
class RedesignedComposeView extends StatelessWidget {
  RedesignedComposeView({super.key});

  final controller = Get.find<ComposeController>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header with visual indicator
          _buildHeader(theme),

          // Main content area with responsive two-pane layout on wide screens
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;

                Widget lastSaved = Obx(
                  () =>
                      controller.lastSavedTime.isNotEmpty
                          ? Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.outline.withValues(
                                  alpha: 0.2,
                                ),
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
                          : const SizedBox.shrink(),
                );

                if (isWide) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left pane: From, Recipients, Subject
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              lastSaved,
                              _buildFromField(theme),
                              const SizedBox(height: 16),
                              _buildRecipientsSection(theme),
                              const SizedBox(height: 16),
                              _buildSubjectField(theme),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Right pane: Editor, Attachments, Signature
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMessageComposer(theme),
                              const SizedBox(height: 16),
                              _buildAttachmentsSection(theme),
                              const SizedBox(height: 16),
                              _buildSignatureSection(theme),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Narrow: stacked layout
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      lastSaved,
                      _buildFromField(theme),
                      const SizedBox(height: 16),
                      _buildRecipientsSection(theme),
                      const SizedBox(height: 16),
                      _buildSubjectField(theme),
                      const SizedBox(height: 16),
                      _buildMessageComposer(theme),
                      const SizedBox(height: 16),
                      _buildAttachmentsSection(theme),
                      const SizedBox(height: 16),
                      _buildSignatureSection(theme),
                      const SizedBox(height: 100), // Bottom padding for FAB
                    ],
                  ),
                );
              },
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
          Icon(Icons.edit_outlined, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            'compose_email'.tr,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          Obx(
            () =>
                controller.hasUnsavedChanges
                    ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withValues(
                          alpha: 0.2,
                        ),
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
                    : const SizedBox(),
          ),
        ],
      ),
    );
  }

  Widget _buildFromField(ThemeData theme) {
    final name = controller.name;
    final email = controller.email;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.alternate_email,
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
                if (name.isNotEmpty) ...[
                  Text(
                    name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                ],
                InkWell(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: email));
                    ScaffoldMessenger.of(Get.context!).showSnackBar(
                      SnackBar(
                        content: Text(
                          'copied_to_clipboard'.trParams({'field': 'email'}),
                        ),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: theme.colorScheme.primary,
                      ),
                    );
                  },
                  child: Text(
                    email,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.1,
                    ),
                    overflow: TextOverflow.ellipsis,
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
      decoration: const BoxDecoration(),
      child: Column(
        children: [
          // To field
          Padding(
            padding: const EdgeInsets.all(16),
            child: Obx(
              () => EnhancedEmailChipsField(
                title: "to".tr,
                icon: Icons.mail_outline,
                emails: controller.toList.toList(),
                onDelete: (int i) => controller.removeFromToList(i),
                onInsert: (MailAddress address) => controller.addTo(address),
                trailingWidget: _buildCcBccToggle(theme),
              ),
            ),
          ),

          // CC/BCC fields with smooth animation
          Obx(
            () => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: controller.isCcAndBccVisible() ? null : 0,
              child:
                  controller.isCcAndBccVisible()
                      ? Column(
                        children: [
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: EnhancedEmailChipsField(
                              title: "CC".tr,
                              icon: Icons.copy_outlined,
                              emails: controller.cclist.toList(),
                              onDelete:
                                  (int i) => controller.removeFromCcList(i),
                              onInsert:
                                  (MailAddress address) =>
                                      controller.addToCC(address),
                            ),
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: EnhancedEmailChipsField(
                              title: "bcc".tr,
                              icon: Icons.visibility_off_outlined,
                              emails: controller.bcclist.toList(),
                              onDelete:
                                  (int i) => controller.removeFromBccList(i),
                              onInsert:
                                  (MailAddress address) =>
                                      controller.addToBcc(address),
                            ),
                          ),
                        ],
                      )
                      : const SizedBox(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCcBccToggle(ThemeData theme) {
    return Obx(
      () => InkWell(
        onTap: () => controller.isCcAndBccVisible.toggle(),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:
                controller.isCcAndBccVisible()
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
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
                color:
                    controller.isCcAndBccVisible()
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                controller.isCcAndBccVisible() ? 'hide_cc_bcc'.tr : 'cc_bcc'.tr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color:
                      controller.isCcAndBccVisible()
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectField(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: TextFormField(
        controller: controller.subjectController,
        decoration: InputDecoration(
          hintText: "subject".tr,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAttachmentsSection(ThemeData theme) {
    return Obx(() {
      final hasSelected = controller.attachments.isNotEmpty;
      final hasPending = controller.pendingDraftAttachments.isNotEmpty;
      if (!hasSelected && !hasPending) return const SizedBox();

      return Container(
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
            // Pending draft attachments (metadata only)
            if (hasPending) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.cloud_download_outlined,
                      color: theme.colorScheme.secondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'draft_attachments'.trParams({
                        'count': '${controller.pendingDraftAttachments.length}',
                      }),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: controller.reattachAllPendingAttachments,
                    icon: const Icon(Icons.playlist_add),
                    label: Text('attach_all'.tr),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...controller.pendingDraftAttachments.map(
                (m) => PendingDraftAttachmentTile(
                  meta: m,
                  onReattach: () => controller.reattachPendingAttachment(m),
                  onView: () => controller.viewPendingAttachment(m),
                ),
              ),
              if (hasSelected) const SizedBox(height: 16),
              if (hasSelected) const Divider(height: 1),
              if (hasSelected) const SizedBox(height: 12),
            ],

            // Selected attachments (files chosen or reattached)
            if (hasSelected) ...[
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
          ],
        ),
      );
    });
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
          Obx(
            () => AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child:
                  controller.isHtml.isTrue
                      ? _buildHtmlEditor(theme)
                      : _buildPlainTextEditor(theme),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHtmlEditor(ThemeData theme) {
    final isWide = MediaQuery.of(Get.context!).size.width > 900;
    final editorHeight = isWide ? 420.0 : 300.0;
    return SizedBox(
      key: const ValueKey('html_editor'),
      height: editorHeight,
      child: HtmlEditor(
        controller: controller.htmlController,
        htmlToolbarOptions: const HtmlToolbarOptions(
          renderSeparatorWidget: false,
          toolbarPosition: ToolbarPosition.custom,
          defaultToolbarButtons: [
            FontButtons(),
            ColorButtons(),
            ListButtons(),
            ParagraphButtons(caseConverter: false, textDirection: true),
          ],
        ),
        htmlEditorOptions: HtmlEditorOptions(
          hint: "compose_your_message".tr,
          initialText: controller.bodyPart,
          shouldEnsureVisible: true,
          autoAdjustHeight: false,
          adjustHeightForKeyboard: true,
        ),
        otherOptions: OtherOptions(
          height: editorHeight,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
          ),
        ),
        callbacks: Callbacks(
          onInit: () {
            // Editor is initialized and ready
            debugPrint('HTML Editor initialized successfully');
            controller.markHtmlEditorReady();
            // Apply any preloaded HTML body once the editor is ready
            if (controller.bodyPart.isNotEmpty) {
              try {
                controller.htmlController.setText(controller.bodyPart);
              } catch (_) {}
            }
          },
          onChangeContent: (String? changed) {
            // Handle content changes safely
            if (changed != null) {
              controller.bodyPart = changed;
              controller.hasUnsavedChanges = true;
              // Trigger projection and autosave scheduling
              controller.onContentChanged();
            }
          },
          onFocus: () {
            debugPrint('HTML Editor focused');
          },
          onBlur: () {
            debugPrint('HTML Editor blurred');
          },
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
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
