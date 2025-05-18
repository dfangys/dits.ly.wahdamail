import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';
import 'package:wahda_bank/views/compose/widgets/text_field.dart';

class WComposeView extends StatefulWidget {
  final MimeMessage? draftMessage;

  const WComposeView({
    super.key,
    this.draftMessage,
  });

  @override
  State<WComposeView> createState() => _WComposeViewState();
}

class _WComposeViewState extends State<WComposeView> with SingleTickerProviderStateMixin {
  late final ComposeController controller;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Get or create controller
    controller = Get.find<ComposeController>();

    // Load draft if provided
    if (widget.draftMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        controller.loadDraft(widget.draftMessage!);
      });
    }

    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // From field
            _buildFromField(),

            const SizedBox(height: 16),

            // To field with enhanced styling
            Obx(
                  () => AnimatedEmailsChipsField(
                title: "to".tr,
                emails: controller.toList.toList(),
                onDelete: (int i) {
                  controller.removeFromToList(i);
                },
                onInsert: (MailAddress address) {
                  controller.addTo(address);
                },
                accentColor: AppTheme.primaryColor,
                ccBccWidget: IconButton(
                  onPressed: () {
                    controller.isCcAndBccVisible.toggle();
                  },
                  icon: Icon(
                    controller.isCcAndBccVisible()
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  tooltip: controller.isCcAndBccVisible() ? 'Hide CC/BCC' : 'Show CC/BCC',
                  splashRadius: 20,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // CC and BCC fields with animation
            Obx(
                  () => AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: controller.isCcAndBccVisible()
                    ? Column(
                  children: [
                    const SizedBox(height: 8),
                    AnimatedEmailsChipsField(
                      title: "CC".tr,
                      emails: controller.cclist.toList(),
                      onDelete: (int i) {
                        controller.removeFromCcList(i);
                      },
                      onInsert: (MailAddress address) {
                        controller.addToCC(address);
                      },
                      accentColor: AppTheme.primaryColor.withOpacity(0.8),
                    ),
                    const SizedBox(height: 8),
                    AnimatedEmailsChipsField(
                      title: "BCC".tr,
                      emails: controller.bcclist.toList(),
                      onDelete: (int i) {
                        controller.removeFromBccList(i);
                      },
                      onInsert: (MailAddress add) {
                        controller.addToBcc(add);
                      },
                      accentColor: AppTheme.primaryColor.withOpacity(0.6),
                    ),
                    const SizedBox(height: 8),
                  ],
                )
                    : const SizedBox.shrink(),
              ),
            ),

            // Subject field with enhanced styling
            _buildSubjectField(),

            const SizedBox(height: 16),

            // Attachments section with visual improvements
            _buildAttachmentsSection(),

            const SizedBox(height: 16),

            // Message body with toggle between HTML and plain text
            Expanded(
              child: _buildMessageBody(),
            ),

            // Signature
            _buildSignature(),
          ],
        ),
      ),
    );
  }

  Widget _buildFromField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        controller: controller.fromController,
        readOnly: true,
        decoration: InputDecoration(
          labelText: "from".tr,
          labelStyle: TextStyle(
            color: AppTheme.textSecondaryColor,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        style: TextStyle(
          fontSize: 14,
          color: AppTheme.textPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildSubjectField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextFormField(
        controller: controller.subjectController,
        decoration: InputDecoration(
          labelText: "subject".tr,
          labelStyle: TextStyle(
            color: AppTheme.textSecondaryColor,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        style: TextStyle(
          fontSize: 14,
          color: AppTheme.textPrimaryColor,
        ),
      ),
    );
  }

  Widget _buildAttachmentsSection() {
    return Obx(
          () => controller.attachments.isNotEmpty
          ? Container(
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4, bottom: 8),
              child: Text(
                'Attachments',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                controller.attachments.length,
                    (index) => _buildAttachmentChip(index),
              ),
            ),
          ],
        ),
      )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildAttachmentChip(int index) {
    final fileName = controller.attachments[index].path.split('/').last;
    final fileExtension = fileName.split('.').last.toLowerCase();

    // Determine icon based on file extension
    IconData iconData;
    Color iconColor;

    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(fileExtension)) {
      iconData = Icons.image_outlined;
      iconColor = Colors.blue;
    } else if (['pdf'].contains(fileExtension)) {
      iconData = Icons.picture_as_pdf_outlined;
      iconColor = Colors.red;
    } else if (['doc', 'docx'].contains(fileExtension)) {
      iconData = Icons.description_outlined;
      iconColor = Colors.blue;
    } else if (['xls', 'xlsx'].contains(fileExtension)) {
      iconData = Icons.table_chart_outlined;
      iconColor = Colors.green;
    } else if (['ppt', 'pptx'].contains(fileExtension)) {
      iconData = Icons.slideshow_outlined;
      iconColor = Colors.orange;
    } else if (['zip', 'rar', '7z'].contains(fileExtension)) {
      iconData = Icons.folder_zip_outlined;
      iconColor = Colors.purple;
    } else {
      iconData = Icons.insert_drive_file_outlined;
      iconColor = Colors.grey;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
        ),
      ),
      child: IntrinsicWidth(
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              child: Icon(
                iconData,
                size: 20,
                color: iconColor,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  fileName,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textPrimaryColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 16,
                color: AppTheme.textSecondaryColor,
              ),
              onPressed: () {
                controller.attachments.removeAt(index);
              },
              splashRadius: 16,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBody() {
    return Obx(
          () => Column(
        children: [
          // Format toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Plain Text',
                style: TextStyle(
                  fontSize: 12,
                  color: controller.isHtml.isTrue
                      ? AppTheme.textSecondaryColor
                      : AppTheme.primaryColor,
                  fontWeight: controller.isHtml.isTrue
                      ? FontWeight.normal
                      : FontWeight.bold,
                ),
              ),
              Switch(
                value: controller.isHtml.value,
                onChanged: (value) {
                  controller.isHtml.value = value;
                },
                activeColor: AppTheme.primaryColor,
              ),
              Text(
                'Rich Text',
                style: TextStyle(
                  fontSize: 12,
                  color: controller.isHtml.isTrue
                      ? AppTheme.primaryColor
                      : AppTheme.textSecondaryColor,
                  fontWeight: controller.isHtml.isTrue
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Editor
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: controller.isHtml.isTrue
                  ? _buildHtmlEditor()
                  : _buildPlainTextEditor(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHtmlEditor() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: HtmlEditor(
        controller: controller.htmlController,
        htmlToolbarOptions: const HtmlToolbarOptions(
          renderSeparatorWidget: true,
          defaultToolbarButtons: [
            FontButtons(
              clearAll: true,
              strikethrough: true,
              superscript: true,
              subscript: true,
            ),
            ColorButtons(),
            ListButtons(),
            ParagraphButtons(
              caseConverter: false,
              textDirection: true,
              lineHeight: true,
              alignLeft: true,
              alignCenter: true,
              alignRight: true,
              alignJustify: true,
            ),
            InsertButtons(
              link: true,
              picture: true,
              table: true,
              hr: true,
            ),
          ],
          toolbarPosition: ToolbarPosition.aboveEditor,
          toolbarType: ToolbarType.nativeScrollable,
        ),
        htmlEditorOptions: HtmlEditorOptions(
          hint: "Your message here...",
          initialText: controller.bodyPart,
          shouldEnsureVisible: true,
          autoAdjustHeight: false,
        ),
        otherOptions: const OtherOptions(
          height: 400,
          decoration: BoxDecoration(
            color: Colors.transparent,
          ),
        ),
      ),
    );
  }

  Widget _buildPlainTextEditor() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: TextFormField(
        controller: controller.plainTextController,
        maxLines: null,
        keyboardType: TextInputType.multiline,
        decoration: const InputDecoration(
          hintText: "Your message here...",
          border: InputBorder.none,
        ),
        style: TextStyle(
          fontSize: 14,
          color: AppTheme.textPrimaryColor,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildSignature() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Signature',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          const Divider(),
          HtmlWidget(
            controller.signature,
            textStyle: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
