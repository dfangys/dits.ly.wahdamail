import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:wahda_bank/views/view/controllers/inbox_controller.dart';
import 'package:wahda_bank/views/view/new_message/widgets/to_text_field.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({super.key});

  @override
  State<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final TextEditingController subjectController = TextEditingController();
  final HtmlEditorController htmlController = HtmlEditorController();
  bool _isComposing = false;

  @override
  void dispose() {
    subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(InboxController());
    final user = controller.users[0];

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            stretch: true,
            backgroundColor: AppTheme.surfaceColor,
            elevation: 0,
            scrolledUnderElevation: 2,
            shadowColor: Colors.black.withOpacity(0.1),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
              onPressed: () {
                // Check if there's content before allowing to go back
                if (subjectController.text.isNotEmpty || _isComposing) {
                  _showDiscardDialog();
                } else {
                  Get.back();
                }
              },
              tooltip: 'Back',
              splashRadius: 24,
            ),
            title: Text(
              'New Message',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
            ),
            actions: [
              // Attachment button
              IconButton(
                onPressed: () {
                  // Add attachment functionality
                  _showAttachmentOptions();
                },
                icon: Icon(
                  Icons.attach_file_rounded,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                tooltip: 'Add attachment',
                splashRadius: 24,
              ),

              // Send button
              IconButton(
                onPressed: () {
                  _sendEmail();
                },
                icon: Icon(
                  Icons.send_rounded,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                tooltip: 'Send',
                splashRadius: 24,
              ),

              // More options
              PopupMenuButton(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                offset: const Offset(0, 8),
                onSelected: (value) {
                  switch (value) {
                    case 'draft':
                      _saveAsDraft();
                      break;
                    case 'receipt':
                      _toggleReadReceipt();
                      break;
                    case 'plain_text':
                      _convertToPlainText();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  _buildPopupMenuItem('draft', Icons.save_outlined, 'Save as draft'),
                  _buildPopupMenuItem('receipt', Icons.mark_email_read_outlined, 'Request read receipt'),
                  _buildPopupMenuItem('plain_text', Icons.text_format_outlined, 'Convert to plain text'),
                ],
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: Colors.grey.withOpacity(0.2),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // From field
                    _buildSectionLabel('From'),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                            child: Text(
                              user.name[0].toUpperCase(),
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '"${user.name}" <${user.email}>',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textPrimaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                            onPressed: () {
                              // Show account selection if multiple accounts
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            splashRadius: 20,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // To field
                    _buildSectionLabel('To'),
                    WToTextField(),

                    const SizedBox(height: 16),

                    // Subject field
                    _buildSectionLabel('Subject'),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: TextFormField(
                        controller: subjectController,
                        decoration: InputDecoration(
                          hintText: 'Message Subject',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimaryColor,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Message body
                    _buildSectionLabel('Message'),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: HtmlEditor(
                        controller: htmlController,
                        htmlEditorOptions: const HtmlEditorOptions(
                          hint: "Compose your message here...",
                          shouldEnsureVisible: true,
                          initialText: "<p></p>",
                        ),
                        htmlToolbarOptions: HtmlToolbarOptions(
                          toolbarPosition: ToolbarPosition.aboveEditor,
                          toolbarType: ToolbarType.nativeScrollable,
                          defaultToolbarButtons: [
                            StyleButtons(style: true),
                            FontSettingButtons(
                              fontName: true,
                              fontSize: true,
                            ),
                            FontButtons(
                              bold: true,
                              italic: true,
                              underline: true,
                              clearAll: true,
                            ),
                            ColorButtons(
                              foregroundColor: true,
                            ),
                            ListButtons(
                              ul: true,
                              ol: true,
                              listStyles: true,
                            ),
                            ParagraphButtons(
                              alignLeft: true,
                              alignCenter: true,
                              alignRight: true,
                            ),
                            InsertButtons(
                              link: true,
                              picture: true,
                              table: true,
                              hr: true,
                            ),
                          ],
                          customToolbarButtons: [
                            IconButton(
                              icon: const Icon(Icons.attach_file),
                              onPressed: () {
                                _showAttachmentOptions();
                              },
                            ),
                          ],
                        ),
                        callbacks: Callbacks(
                          onInit: () {
                            htmlController.setFocus();
                          },
                          onChangeContent: (content) {
                            setState(() {
                              _isComposing = content != null &&
                                  content.isNotEmpty &&
                                  content != "<p></p>";
                            });
                          },
                        ),
                      ),
                    ),

                    // Spacer at the bottom for better scrolling
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _isComposing ? FloatingActionButton(
        onPressed: _sendEmail,
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.send_rounded, color: Colors.white),
      ) : null,
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

  PopupMenuItem _buildPopupMenuItem(String value, IconData icon, String text) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Draft?'),
        content: const Text('You have an unsent draft. Do you want to save it or discard it?'),
        actions: [
          TextButton(
            onPressed: () {
              Get.back(); // Close dialog
              Get.back(); // Go back to previous screen
            },
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () {
              Get.back(); // Close dialog
              _saveAsDraft();
              Get.back(); // Go back to previous screen
            },
            child: Text(
              'Save as Draft',
              style: TextStyle(color: AppTheme.primaryColor),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
            const Text(
              'Add Attachment',
              style: TextStyle(
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
                  label: 'Gallery',
                  onTap: () {
                    // Implement gallery attachment
                    Get.back();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: () {
                    // Implement camera attachment
                    Get.back();
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'Document',
                  onTap: () {
                    // Implement document attachment
                    Get.back();
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

  void _sendEmail() {
    // Implement email sending functionality
    Get.snackbar(
      'Email Sent',
      'Your message has been sent successfully',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
    );
    Get.back();
  }

  void _saveAsDraft() {
    // Implement save as draft functionality
    Get.snackbar(
      'Draft Saved',
      'Your message has been saved as a draft',
      backgroundColor: Colors.blue,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
    );
  }

  void _toggleReadReceipt() {
    // Implement read receipt toggle
    Get.snackbar(
      'Read Receipt Enabled',
      'You will be notified when the recipient reads this message',
      backgroundColor: Colors.purple,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
    );
  }

  void _convertToPlainText() {
    // Implement plain text conversion
    Get.snackbar(
      'Converted to Plain Text',
      'Your message has been converted to plain text format',
      backgroundColor: Colors.orange,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
    );
  }
}
