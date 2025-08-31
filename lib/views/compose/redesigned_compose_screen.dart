import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';
import 'package:wahda_bank/views/compose/widgets/redesigned_compose_view.dart';
import 'package:wahda_bank/views/compose/widgets/modern_draft_options_sheet.dart';
import 'package:wahda_bank/views/compose/models/draft_model.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';

/// Redesigned compose screen with enhanced UX and modern design
class RedesignedComposeScreen extends StatefulWidget {
  final DraftModel? draft; // For loading existing drafts
  final String? replyToMessageId; // For reply functionality
  final String? forwardMessageId; // For forward functionality

  const RedesignedComposeScreen({
    super.key,
    this.draft,
    this.replyToMessageId,
    this.forwardMessageId,
  });

  @override
  State<RedesignedComposeScreen> createState() => _RedesignedComposeScreenState();
}

class _RedesignedComposeScreenState extends State<RedesignedComposeScreen>
    with TickerProviderStateMixin {
  final composeFormKey = GlobalKey<FormState>();
  late ComposeController controller;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;
  late AnimationController _slideAnimationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize controller (use existing if already registered to allow test injection)
    if (Get.isRegistered<ComposeController>()) {
      controller = Get.find<ComposeController>();
    } else {
      controller = Get.put(ComposeController());
    }
    
    // Initialize animations
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.elasticOut,
    ));

    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideAnimationController,
      curve: Curves.easeOutCubic,
    ));

    // Start animations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _slideAnimationController.forward();
      Future.delayed(const Duration(milliseconds: 200), () {
        _fabAnimationController.forward();
      });
      
      // Load draft if provided
      if (widget.draft != null) {
        _loadDraft(widget.draft!);
      }
      
      // Handle reply/forward
      if (widget.replyToMessageId != null) {
        _handleReply(widget.replyToMessageId!);
      } else if (widget.forwardMessageId != null) {
        _handleForward(widget.forwardMessageId!);
      }
    });
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _slideAnimationController.dispose();
    super.dispose();
  }

  void _loadDraft(DraftModel draft) {
    // Load draft data into controller
    controller.subjectController.text = draft.subject;

    // Body: for HTML, prefer setting bodyPart so HtmlEditor initialText can use it;
    // onInit will also apply it safely once the editor is ready.
    if (draft.isHtml) {
      controller.isHtml.value = true;
      controller.bodyPart = draft.body;
    } else {
      controller.isHtml.value = false;
      controller.plainTextController.text = draft.body;
    }

    // Load recipients (parse "Name <email>" correctly)
    controller.toList.clear();
    controller.toList.addAll(draft.to.map((value) => MailAddress.parse(value)));

    controller.cclist.clear();
    controller.cclist.addAll(draft.cc.map((value) => MailAddress.parse(value)));

    controller.bcclist.clear();
    controller.bcclist.addAll(draft.bcc.map((value) => MailAddress.parse(value)));

    // Load attachments
    controller.attachments.clear();
    for (final path in draft.attachmentPaths) {
      try {
        final file = File(path);
        if (file.existsSync()) {
          controller.attachments.add(file);
        }
      } catch (e) {
        debugPrint('Error loading attachment: $e');
      }
    }

    // Show CC/BCC if they have content
    if (draft.cc.isNotEmpty || draft.bcc.isNotEmpty) {
      controller.isCcAndBccVisible.value = true;
    }

    // Record server draft context (UID + mailbox) for replace-on-save flow
    try {
      final mbc = Get.find<MailBoxController>();
      final draftsMb = mbc.draftsMailbox ?? mbc.currentMailbox ?? mbc.mailService.client.selectedMailbox;
      controller.setEditingDraftContext(uid: draft.serverUid, mailbox: draftsMb);
    } catch (_) {}
    
    // Mark as loaded from draft
    controller.currentDraftId = draft.id;
    controller.hasUnsavedChanges = false;
  }

  void _handleReply(String messageId) {
    // Implement reply logic
    // This would typically load the original message and set up reply context
  }

  void _handleForward(String messageId) {
    // Implement forward logic
    // This would typically load the original message for forwarding
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: controller.canPop(),
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _handleBackPress();
        }
      },
      child: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          // Cmd/Ctrl + Enter to send
          LogicalKeySet(
            LogicalKeyboardKey.meta, LogicalKeyboardKey.enter,
          ): const ActivateIntent(),
          LogicalKeySet(
            LogicalKeyboardKey.control, LogicalKeyboardKey.enter,
          ): const ActivateIntent(),
          // Cmd/Ctrl + S to save draft
          LogicalKeySet(
            LogicalKeyboardKey.meta, LogicalKeyboardKey.keyS,
          ): const ActivateIntent(),
          LogicalKeySet(
            LogicalKeyboardKey.control, LogicalKeyboardKey.keyS,
          ): const ActivateIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (intent) {
                // Heuristic: if subject or body focused longer, treat as send (Enter shortcut);
                // otherwise, save draft on S.
                // We can't differentiate intents easily with shared ActivateIntent,
                // so default to save on S by checking currently pressed keys.
                final keysPressed = RawKeyboard.instance.keysPressed;
                if (keysPressed.contains(LogicalKeyboardKey.enter)) {
                  _sendEmail();
                } else if (keysPressed.contains(LogicalKeyboardKey.keyS)) {
                  _saveDraft();
                }
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              backgroundColor: theme.colorScheme.surface,
              appBar: _buildAppBar(theme),
              body: SlideTransition(
                position: _slideAnimation,
                child: Form(
                  key: composeFormKey,
                  child: RedesignedComposeView(),
                ),
              ),
              floatingActionButton: _buildFloatingActionButton(theme),
              floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    return AppBar(
      elevation: 0,
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_rounded,
          color: theme.colorScheme.onSurface,
        ),
        onPressed: _handleBackPress,
      ),
      title: Text(
        widget.draft != null ? 'edit_draft'.tr : 'new_message'.tr,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        // Draft status indicator with color coding (like original)
        Obx(() => controller.draftStatus.isNotEmpty
            ? Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getDraftStatusColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getDraftStatusColor().withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (controller.draftStatus == 'saving_draft'.tr) ...[
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _getDraftStatusColor(),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ] else ...[
                      Icon(
                        _getDraftStatusIcon(),
                        size: 12,
                        color: _getDraftStatusColor(),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      controller.draftStatus,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _getDraftStatusColor(),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.shrink()),
        
        // Send button (with accessibility)
        Obx(() => Semantics(
          button: true,
          label: 'send_email'.tr,
          child: IconButton(
            onPressed: controller.isSending.value ? null : _sendEmail,
            icon: controller.isSending.value
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Icon(
                    Icons.send_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
            tooltip: 'send_email'.tr,
          ),
        )),
        
        // Attachment button
        IconButton(
          onPressed: _showAttachmentOptions,
          icon: Icon(
            Icons.attach_file_rounded,
            color: theme.colorScheme.onSurfaceVariant,
            size: 22,
          ),
          tooltip: 'attach_file'.tr,
        ),
        
        // More options button
        IconButton(
          onPressed: _showMoreOptions,
          icon: Icon(
            Icons.more_vert_rounded,
            color: theme.colorScheme.onSurfaceVariant,
            size: 22,
          ),
          tooltip: 'more_options'.tr,
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton(ThemeData theme) {
    return ScaleTransition(
      scale: _fabScaleAnimation,
      child: Obx(() => Semantics(
        button: true,
        label: controller.isSending.value ? 'sending'.tr : 'send_email'.tr,
        child: FloatingActionButton.extended(
          onPressed: controller.isSending.value ? null : _sendEmail,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          elevation: 8,
          icon: controller.isSending.value
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.onPrimary,
                    ),
                  ),
                )
              : const Icon(Icons.send_rounded),
          label: Text(
            controller.isSending.value ? 'sending'.tr : 'send'.tr,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
      )),
    );
  }

  Future<void> _handleBackPress() async {
    if (controller.hasUnsavedChanges) {
      final result = await _showUnsavedChangesDialog();
      if (result == 'save') {
        await _saveDraft();
        if (mounted) Navigator.pop(context);
      } else if (result == 'discard') {
        if (mounted) Navigator.pop(context);
      }
      // If result is null (cancelled), do nothing
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<String?> _showUnsavedChangesDialog() async {
    final theme = Theme.of(context);
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'unsaved_changes'.tr,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'unsaved_changes_message'.tr,
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
            ),
            child: Text('discard'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text('save_draft'.tr),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDraft() async {
    try {
      await controller.saveAsDraft();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('draft_saved'.tr),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_saving_draft'.tr),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  Future<void> _sendEmail() async {
    if (!composeFormKey.currentState!.validate()) {
      return;
    }

    if (controller.toList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('add_recipient_error'.tr),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    try {
      await controller.sendEmail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('email_sent'.tr),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        // Do not pop here; controller.sendEmail already closes the compose view.
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('error_sending_email'.tr),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }


  // void _showScheduleDialog() {
  //   // Implement schedule send functionality
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Text('schedule_send'.tr),
  //       content: Text('schedule_send_feature_coming_soon'.tr),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: Text('ok'.tr),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  //
  // void _showDiscardDialog() {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Text('discard_draft'.tr),
  //       content: Text('discard_draft_confirmation'.tr),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: Text('cancel'.tr),
  //         ),
  //         FilledButton(
  //           onPressed: () {
  //             Navigator.pop(context); // Close dialog
  //             Navigator.pop(context); // Close compose screen
  //           },
  //           style: FilledButton.styleFrom(
  //             backgroundColor: Theme.of(context).colorScheme.error,
  //           ),
  //           child: Text('discard'.tr),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Draft status color coding (like original implementation)
  Color _getDraftStatusColor() {
    if (controller.draftStatus == 'draft_saved'.tr) {
      return Colors.green;
    } else if (controller.draftStatus == 'saving_draft'.tr) {
      return Colors.orange;
    } else if (controller.draftStatus == 'unsaved_changes'.tr) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }

  IconData _getDraftStatusIcon() {
    if (controller.draftStatus == 'draft_saved'.tr) {
      return Icons.check_circle_outline;
    } else if (controller.draftStatus == 'unsaved_changes'.tr) {
      return Icons.circle;
    } else {
      return Icons.info_outline;
    }
  }

  void _showAttachmentOptions() {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            Text(
              'attach_file'.tr,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Options
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
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
                  color: Colors.green.withValues(alpha: 0.1),
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
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ModernDraftOptionsSheet(),
    );
  }
}

