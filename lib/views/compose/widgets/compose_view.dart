import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';
import 'package:wahda_bank/views/compose/widgets/text_field.dart';

class WComposeView extends StatelessWidget {
  WComposeView({
    super.key,
  });

  final controller = Get.find<ComposeController>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header section with from field and recipients
          _buildHeaderSection(context),

          // Subject field
          _buildSubjectField(context),

          // Attachments section
          _buildAttachmentsSection(),

          // Content editor section
          _buildContentEditorSection(context),

          // Signature section
          _buildSignatureSection(),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // From field
            _buildFromField(),

            const SizedBox(height: 8),

            // To field with recipients
            Obx(
                  () => ToEmailsChipsField(
                title: "to".tr,
                emails: controller.toList.toList(),
                onDelete: (int i) {
                  controller.toList.removeAt(i);
                },
                onInsert: (MailAddress address) {
                  controller.addTo(address);
                },
                ccBccWidget: _buildCcBccToggle(),
              ),
            ),

            const Divider(height: 16, thickness: 1),

            // CC/BCC fields (animated visibility)
            _buildCcBccSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildFromField() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.person_outline, size: 18, color: Colors.grey.shade600),
          SizedBox(width: 8),
          Text(
            "from".tr,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: controller.fromController,
              readOnly: true,
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              style: TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCcBccToggle() {
    return Obx(() => AnimatedContainer(
      duration: Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: controller.isCcAndBccVisible()
            ? Colors.blue.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        onPressed: () {
          controller.isCcAndBccVisible.toggle();
        },
        icon: Icon(
          controller.isCcAndBccVisible()
              ? Icons.expand_less
              : Icons.expand_more,
          color: controller.isCcAndBccVisible()
              ? Colors.blue
              : Colors.grey,
          size: 20,
        ),
        tooltip: controller.isCcAndBccVisible()
            ? "hide_cc_bcc".tr
            : "show_cc_bcc".tr,
        splashRadius: 20,
      ),
    ));
  }

  Widget _buildCcBccSection() {
    return Obx(
          () => AnimatedCrossFade(
        crossFadeState: controller.isCcAndBccVisible()
            ? CrossFadeState.showFirst
            : CrossFadeState.showSecond,
        firstChild: Column(
          children: [
            ToEmailsChipsField(
              title: "CC".tr,
              emails: controller.cclist.toList(),
              onDelete: (int i) {
                controller.toList.removeAt(i);
              },
              onInsert: (MailAddress address) {
                controller.addCc(address);
              },
            ),
            const Divider(height: 16, thickness: 1),
            ToEmailsChipsField(
              title: "bcc".tr,
              emails: controller.bcclist.toList(),
              onDelete: (int i) {
                controller.toList.removeAt(i);
              },
              onInsert: (MailAddress add) {
                controller.addBcc(add);
              },
            ),
          ],
        ),
        secondChild: const SizedBox(),
        duration: const Duration(milliseconds: 300),
      ),
    );
  }

  Widget _buildSubjectField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextFormField(
        controller: controller.subjectController,
        decoration: InputDecoration(
          labelText: "subject".tr,
          prefixIcon: Icon(Icons.subject, size: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Theme.of(context).primaryColor),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
        style: TextStyle(fontSize: 15),
      ),
    );
  }

  Widget _buildAttachmentsSection() {
    return Obx(
          () => controller.attachments.isNotEmpty
          ? Container(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 12, bottom: 4),
              child: Text(
                "attachments".tr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: controller.attachments.length,
              itemBuilder: (context, index) {
                final fileName = controller.attachments[index].path.split('/').last;
                final fileExt = fileName.split('.').last.toLowerCase();

                IconData fileIcon;
                Color iconColor;

                // Determine icon based on file extension
                if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(fileExt)) {
                  fileIcon = Icons.image;
                  iconColor = Colors.blue;
                } else if (['pdf'].contains(fileExt)) {
                  fileIcon = Icons.picture_as_pdf;
                  iconColor = Colors.red;
                } else if (['doc', 'docx'].contains(fileExt)) {
                  fileIcon = Icons.description;
                  iconColor = Colors.indigo;
                } else if (['xls', 'xlsx'].contains(fileExt)) {
                  fileIcon = Icons.table_chart;
                  iconColor = Colors.green;
                } else {
                  fileIcon = Icons.insert_drive_file;
                  iconColor = Colors.orange;
                }

                return ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(fileIcon, color: iconColor, size: 20),
                  ),
                  title: Text(
                    fileName,
                    style: TextStyle(fontSize: 14),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.close, size: 18),
                    onPressed: () {
                      controller.attachments.removeAt(index);
                    },
                    splashRadius: 20,
                  ),
                  dense: true,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
          ],
        ),
      )
          : SizedBox(),
    );
  }

  Widget _buildContentEditorSection(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Editor type toggle
          _buildEditorToggle(),

          // Editor content
          _buildEditor(context),
        ],
      ),
    );
  }

  Widget _buildEditorToggle() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            "plain_text".tr,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          Obx(
                () => Switch(
              value: controller.isHtml.value,
              onChanged: (value) {
                controller.toggleHtmlMode();
              },
              activeColor: Colors.blue,
            ),
          ),
          Text(
            "rich_text".tr,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    return Obx(
          () => AnimatedCrossFade(
        firstChild: Container(
          height: 400,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: HtmlEditor(
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
              autoAdjustHeight: false,
            ),
            otherOptions: const OtherOptions(
              height: 400,
              decoration: BoxDecoration(
                color: Colors.transparent,
              ),
            ),
          ),
        ),
        secondChild: Container(
          height: 400,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: controller.plainTextController,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: "Your message here...",
              border: InputBorder.none,
            ),
            style: TextStyle(fontSize: 15),
          ),
        ),
        crossFadeState: controller.isHtml.isTrue
            ? CrossFadeState.showFirst
            : CrossFadeState.showSecond,
        duration: const Duration(milliseconds: 300),
      ),
    );
  }

  Widget _buildSignatureSection() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              "signature".tr,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          HtmlWidget(
            controller.signature,
            textStyle: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
