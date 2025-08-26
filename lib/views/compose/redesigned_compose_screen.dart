import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';
import 'package:wahda_bank/views/compose/widgets/redesigned_compose_view.dart';
import 'package:wahda_bank/views/compose/models/draft_model.dart';
import 'package:intl/intl.dart';

import '../../utills/funtions.dart';

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
    
    // Initialize controller
    controller = Get.put(ComposeController());
    
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
    
    if (draft.isHtml) {
      controller.isHtml.value = true;
      controller.htmlController.setText(draft.body);
    } else {
      controller.isHtml.value = false;
      controller.plainTextController.text = draft.body;
    }
    
    // Load recipients
    controller.toList.clear();
    controller.toList.addAll(draft.to.map((email) => MailAddress('', email)));
    
    controller.cclist.clear();
    controller.cclist.addAll(draft.cc.map((email) => MailAddress('', email)));
    
    controller.bcclist.clear();
    controller.bcclist.addAll(draft.bcc.map((email) => MailAddress('', email)));
    
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
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _handleBackPress();
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.background,
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
        // Save as draft button
        Obx(() => IconButton(
          icon: Icon(
            Icons.save_outlined,
            color: controller.hasUnsavedChanges
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          onPressed: controller.hasUnsavedChanges
              ? () => _saveDraft()
              : null,
          tooltip: 'save_draft'.tr,
        )),
        
        // More options
        PopupMenuButton<String>(
          icon: Icon(
            Icons.more_vert_rounded,
            color: theme.colorScheme.onSurface,
          ),
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'schedule',
              child: Row(
                children: [
                  Icon(Icons.schedule_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text('schedule_send'.tr),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'discard',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
                  const SizedBox(width: 12),
                  Text('discard_draft'.tr, style: TextStyle(color: theme.colorScheme.error)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton(ThemeData theme) {
    return ScaleTransition(
      scale: _fabScaleAnimation,
      child: Obx(() => FloatingActionButton.extended(
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
        Navigator.pop(context);
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

  void _handleMenuAction(String action) {
    switch (action) {
      case 'schedule':
        _showScheduleDialog();
        break;
      case 'discard':
        _showDiscardDialog();
        break;
    }
  }

  void _showScheduleDialog() {
    // Implement schedule send functionality
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('schedule_send'.tr),
        content: Text('schedule_send_feature_coming_soon'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('ok'.tr),
          ),
        ],
      ),
    );
  }

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('discard_draft'.tr),
        content: Text('discard_draft_confirmation'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close compose screen
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text('discard'.tr),
          ),
        ],
      ),
    );
  }
}

