import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import '../../../app/controllers/settings_controller.dart';

class SignatureSheet extends StatefulWidget {
  const SignatureSheet({super.key});

  @override
  State<SignatureSheet> createState() => _SignatureSheetState();
}

class _SignatureSheetState extends State<SignatureSheet> {
  final htmlController = HtmlEditorController();
  final controller = Get.find<SettingController>();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialize with a small delay to ensure proper loading
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.only(bottom: bottomPadding),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar for dragging
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha : 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header with actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.withValues(alpha : 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Title
                  Text(
                    "Edit Signature",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),

                  // Save button
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () async {
                      final text = await htmlController.getText();
                      controller.signature(text);
                      Get.back();
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(),

            // Toolbar actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Toggle code view
                  Obx(() => IconButton(
                    icon: Icon(
                      controller.signatureCodeView()
                          ? Icons.code_off
                          : Icons.code,
                      color: controller.signatureCodeView()
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha : 0.7),
                    ),
                    tooltip: 'Toggle HTML Code View',
                    onPressed: () {
                      controller.signatureCodeView.toggle();
                      htmlController.toggleCodeView();
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: controller.signatureCodeView()
                          ? theme.colorScheme.primary.withValues(alpha : 0.1)
                          : Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  )),

                  // Clear signature
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Clear Signature',
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Clear Signature'),
                          content: const Text('Are you sure you want to clear your signature?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                controller.signature("");
                                htmlController.setText("");
                                Navigator.pop(context);
                              },
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      );
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withValues(alpha : 0.1),
                      foregroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Insert template button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Insert Template'),
                    onPressed: () {
                      _showTemplateOptions(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // HTML Editor
            _isLoading
                ? const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            )
                : SizedBox(
              height: 400,
              child: HtmlEditor(
                controller: htmlController,
                htmlEditorOptions: HtmlEditorOptions(
                  hint: "Your signature here...",
                  initialText: controller.signature(),
                  shouldEnsureVisible: true,
                  autoAdjustHeight: false,
                ),
                htmlToolbarOptions: const HtmlToolbarOptions(
                  defaultToolbarButtons: [
                    StyleButtons(),
                    // FontButtons(fontName: true, fontSize: true),
                    FontSettingButtons(
                      fontSizeUnit: false,
                    ),
                    ColorButtons(),
                    ParagraphButtons(
                      textDirection: true,
                      lineHeight: false,
                      caseConverter: false,
                    ),
                    ListButtons(),
                    InsertButtons(
                      link: true,
                      picture: true,
                      audio: false,
                      video: false,
                      table: false,
                      hr: true,
                    ),
                  ],
                  toolbarPosition: ToolbarPosition.aboveEditor,
                  toolbarType: ToolbarType.nativeScrollable,
                ),
                otherOptions: const OtherOptions(
                  height: 400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTemplateOptions(BuildContext context) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Signature Templates',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),

              // Simple template
              _buildTemplateOption(
                context,
                title: 'Simple',
                description: 'Clean, minimal signature with name and title',
                onTap: () {
                  final name = controller.accountName();
                  // final email = Get.find<MailBoxController>().account.email;

                  final template = '''
                  <div style="font-family: Arial, sans-serif; color: #333333;">
                    <p><strong>$name</strong><br>
                    <span style="color: #666666;">Email: </span></p>
                  </div>
                  ''';

                  htmlController.setText(template);
                  Navigator.pop(context);
                },
              ),

              const Divider(),

              // Professional template
              _buildTemplateOption(
                context,
                title: 'Professional',
                description: 'Business signature with contact details',
                onTap: () {
                  final name = controller.accountName();
                  // final email = Get.find<MailBoxController>().account.email;

                  final template = '''
                  <div style="font-family: Arial, sans-serif; color: #333333;">
                    <p><strong style="font-size: 16px;">$name</strong><br>
                    <span style="color: #666666;">Wahda Bank</span><br>
                    <span style="color: #666666;">Email: </span><br>
                    <span style="color: #666666;">Phone: +218 XX XXX XXXX</span></p>
                    <p style="border-top: 1px solid #dddddd; padding-top: 8px; color: #999999; font-size: 12px;">
                      This email and any files transmitted with it are confidential and intended solely for the use of the individual or entity to whom they are addressed.
                    </p>
                  </div>
                  ''';

                  htmlController.setText(template);
                  Navigator.pop(context);
                },
              ),

              const Divider(),

              // Colorful template
              _buildTemplateOption(
                context,
                title: 'Colorful',
                description: 'Vibrant signature with accent colors',
                onTap: () {
                  final name = controller.accountName();
                  // final email = Get.find<MailBoxController>().account.email;

                  final template = '''
                  <div style="font-family: Arial, sans-serif;">
                    <p><strong style="font-size: 18px; color: #1a73e8;">$name</strong><br>
                    <span style="color: #666666;">Wahda Bank</span><br>
                    <span style="color: #666666;">Email: <a href="mailto:" style="color: #1a73e8; text-decoration: none;"></a></span></p>
                    <p>
                      <span style="display: inline-block; background-color: #1a73e8; color: white; padding: 4px 8px; border-radius: 4px; margin-right: 8px;">Website</span>
                      <span style="display: inline-block; background-color: #34a853; color: white; padding: 4px 8px; border-radius: 4px; margin-right: 8px;">LinkedIn</span>
                      <span style="display: inline-block; background-color: #ea4335; color: white; padding: 4px 8px; border-radius: 4px;">Twitter</span>
                    </p>
                  </div>
                  ''';

                  htmlController.setText(template);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTemplateOption(
      BuildContext context, {
        required String title,
        required String description,
        required VoidCallback onTap,
      }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha : 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.description,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha : 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha : 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
