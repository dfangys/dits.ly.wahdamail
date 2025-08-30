import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';
import 'package:wahda_bank/views/compose/widgets/redesigned_compose_view.dart';

/// Floating compose modal for desktop/tablet; falls back to full-screen on mobile via launcher helper.
class ComposeModal extends StatefulWidget {
  const ComposeModal({super.key});

  static Future<void> show(BuildContext context, {Map<String, dynamic>? arguments}) async {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 900;
    if (isWide) {
      await Get.dialog(
        Dialog(
          insetPadding: const EdgeInsets.all(16),
          clipBehavior: Clip.antiAlias,
          backgroundColor: Theme.of(context).colorScheme.surface,
          child: const ComposeModal(),
        ),
        barrierDismissible: false,
        arguments: arguments,
      );
    } else {
      // Mobile: use full-screen compose
      await Get.toNamed('/compose-full', arguments: arguments, preventDuplicates: false);
    }
  }

  @override
  State<ComposeModal> createState() => _ComposeModalState();
}

class _ComposeModalState extends State<ComposeModal> with TickerProviderStateMixin {
  late ComposeController controller;
  bool minimized = false;

  @override
  void initState() {
    super.initState();
    controller = Get.put(ComposeController());
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * (minimized ? 0.12 : 0.85);
    final maxWidth = MediaQuery.of(context).size.width * 0.65;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: maxWidth.clamp(640.0, 980.0),
      height: maxHeight.clamp(120.0, 900.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
      ),
      child: Column(
        children: [
          _buildHeader(theme),
          const Divider(height: 1),
          if (!minimized)
            Expanded(
              child: RedesignedComposeView(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          // Close
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded, size: 18),
            color: theme.colorScheme.onSurface,
            onPressed: () async {
              if (controller.hasUnsavedChanges) {
                // Prompt to save
                final res = await _confirmClose();
                if (res == 'save') {
                  await controller.saveAsDraft();
                  Get.back();
                } else if (res == 'discard') {
                  Get.back();
                }
              } else {
                Get.back();
              }
            },
          ),
          // Minimize toggle
          IconButton(
            tooltip: minimized ? 'Expand' : 'Minimize',
            icon: Icon(minimized ? Icons.open_in_full_rounded : Icons.minimize_rounded, size: 18),
            color: theme.colorScheme.onSurfaceVariant,
            onPressed: () => setState(() => minimized = !minimized),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'compose_email'.tr,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          // Save draft
          TextButton.icon(
            onPressed: controller.isBusy.value ? null : () => controller.saveAsDraft(),
            icon: const Icon(Icons.save_outlined, size: 18),
            label: Text('save_draft'.tr),
          ),
          const SizedBox(width: 8),
          // Send (primary)
          Obx(() => FilledButton.icon(
                onPressed: controller.isSending.value ? null : () async {
                  // Basic validations happen inside controller
                  await controller.sendEmail();
                  // controller will close view on success; this dialog will pop due to Get.back()
                },
                icon: controller.isSending.value
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary),
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text('send'.tr),
              )),
        ],
      ),
    );
  }

  Future<String?> _confirmClose() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('unsaved_changes'.tr),
        content: Text('unsaved_changes_message'.tr),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('cancel'.tr)),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text('discard'.tr),
          ),
          FilledButton(onPressed: () => Navigator.pop(context, 'save'), child: Text('save_draft'.tr)),
        ],
      ),
    );
  }
}

