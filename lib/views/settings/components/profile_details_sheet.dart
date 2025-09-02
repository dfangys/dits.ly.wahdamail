import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/views/settings/pages/security_page.dart';

class ProfileDetailsSheet extends GetView<SettingController> {
  const ProfileDetailsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 24),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ULTRA MODERN HEADER CARD
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.75),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.35),
                        shape: BoxShape.circle,
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Obx(
                          () => Text(
                            (controller.userName().isNotEmpty
                                    ? controller.userName()[0]
                                    : (controller.userEmail().isNotEmpty
                                        ? controller.userEmail()[0]
                                        : 'U'))
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Name, Email and chips
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Obx(
                            () => Text(
                              controller.userName().isNotEmpty
                                  ? controller.userName()
                                  : controller.accountName(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Obx(() {
                            final email =
                                controller.userEmail().isNotEmpty
                                    ? controller.userEmail()
                                    : (Get.find<SettingController>().box
                                            .read('email')
                                            ?.toString() ??
                                        '');
                            return Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    email,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.9),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  splashRadius: 18,
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                  onPressed:
                                      email.isEmpty
                                          ? null
                                          : () async {
                                            await Clipboard.setData(
                                              ClipboardData(text: email),
                                            );
                                            Get.snackbar(
                                              'Copied',
                                              'Email copied to clipboard',
                                              snackPosition:
                                                  SnackPosition.BOTTOM,
                                            );
                                          },
                                ),
                              ],
                            );
                          }),
                          const SizedBox(height: 10),
                          // Chips row
                          Obx(() {
                            final usage = controller.usageLabel();
                            final quota = controller.quotaLabel();
                            final twofa = controller.twoFactorEnabled();
                            return Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _chip(
                                  icon: Icons.storage_rounded,
                                  label: usage.isNotEmpty ? usage : 'Usage',
                                  theme: theme,
                                ),
                                _chip(
                                  icon: Icons.inventory_2_rounded,
                                  label: quota.isNotEmpty ? quota : 'Plan',
                                  theme: theme,
                                ),
                                _chip(
                                  icon:
                                      twofa
                                          ? Icons.verified_user_rounded
                                          : Icons.shield_outlined,
                                  label: twofa ? '2FA On' : '2FA Off',
                                  theme: theme,
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 16),
              Divider(color: theme.dividerColor.withValues(alpha: 0.1)),
              const SizedBox(height: 8),

              // Account section
              Text(
                'Account',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Obx(
                  () => _infoRow(
                    icon: Icons.phone_rounded,
                    label: 'Phone',
                    value:
                        controller.userPhone().isNotEmpty
                            ? controller.userPhone()
                            : '-',
                    theme: theme,
                    trailing: IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      onPressed:
                          controller.userPhone().isEmpty
                              ? null
                              : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: controller.userPhone()),
                                );
                                Get.snackbar(
                                  'Copied',
                                  'Phone number copied to clipboard',
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                              },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Storage
              Text(
                'Storage',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              Obx(() {
                final percent = controller.usagePercent().clamp(0.0, 100.0);
                final label =
                    controller.usageLabel().isNotEmpty
                        ? '${controller.usageLabel()} of ${controller.quotaLabel()}'
                        : (controller.quotaLabel().isNotEmpty
                            ? controller.quotaLabel()
                            : '');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: percent / 100.0,
                        minHeight: 10,
                        color: theme.colorScheme.primary,
                        backgroundColor: theme.colorScheme.primary.withOpacity(
                          0.15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                        Text(
                          '${percent.toStringAsFixed(1)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }),

              const SizedBox(height: 16),
              Divider(color: theme.dividerColor.withValues(alpha: 0.1)),
              const SizedBox(height: 8),

              // Security
              Text(
                'Security',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 8),
              // Two-factor toggle
              Obx(() {
                final enabled = controller.twoFactorEnabled();
                final updating = controller.twoFactorUpdating();
                final status = controller.twoFactorStatus();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.shield_rounded,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Two-factor Authentication',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                enabled ? 'Enabled' : 'Disabled',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (updating)
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary,
                            ),
                          )
                        else
                          Switch.adaptive(
                            value: enabled,
                            onChanged: (v) async {
                              final ok = await controller.setTwoFactor(v);
                              if (!ok) {
                                // revert UI
                                controller.twoFactorEnabled.toggle();
                                Get.snackbar(
                                  'Error',
                                  'Failed to update 2FA',
                                  snackPosition: SnackPosition.BOTTOM,
                                );
                              }
                            },
                            activeTrackColor: theme.colorScheme.primary
                                .withValues(alpha: 0.3),
                          ),
                      ],
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child:
                          status.isEmpty
                              ? const SizedBox.shrink()
                              : Container(
                                key: ValueKey(status),
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      status == 'success'
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        status == 'success'
                                            ? Colors.green
                                            : Colors.red,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      status == 'success'
                                          ? Icons.check_circle
                                          : Icons.error_outline,
                                      size: 18,
                                      color:
                                          status == 'success'
                                              ? Colors.green
                                              : Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        status == 'success'
                                            ? 'Two-factor settings saved'
                                            : 'Failed to update two-factor settings',
                                        style: TextStyle(
                                          color:
                                              status == 'success'
                                                  ? Colors.green.shade800
                                                  : Colors.red.shade800,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                    ),
                  ],
                );
              }),

              const SizedBox(height: 12),

              // Footer actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: controller.fetchUserProfile,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Refresh'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => Get.to(() => const SecurityPage()),
                    icon: const Icon(Icons.admin_panel_settings_rounded),
                    label: const Text('Security Center'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    required ThemeData theme,
    Widget? trailing,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}

Widget _chip({
  required IconData icon,
  required String label,
  required ThemeData theme,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.4)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}
