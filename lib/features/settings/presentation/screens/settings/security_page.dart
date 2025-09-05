import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/app/controllers/auth_controller.dart';

class SecurityPage extends GetView<SettingController> {
  const SecurityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'security'.tr,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor:
            isDarkMode
                ? Colors.black.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.9),
        foregroundColor: theme.colorScheme.primary,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with explanation
            _buildInfoCard(
              context,
              icon: Icons.shield_rounded,
              text: 'Enhance your email security with these settings',
              isDarkMode: isDarkMode,
            ),

            // App Lock Section
            _buildSectionHeader(
              context,
              title: 'app_lock'.tr,
              icon: Icons.lock_rounded,
              isDarkMode: isDarkMode,
            ),

            // App Lock Card
            _buildAppLockCard(context, isDarkMode),

            // Privacy Section
            _buildSectionHeader(
              context,
              title: 'privacy'.tr,
              icon: Icons.privacy_tip_rounded,
              isDarkMode: isDarkMode,
            ),

            // Privacy Card
            _buildPrivacyCard(context, isDarkMode),

            // Advanced Security Section
            _buildSectionHeader(
              context,
              title: 'advanced_security'.tr,
              icon: Icons.security_rounded,
              isDarkMode: isDarkMode,
            ),

            // Advanced Security Card
            _buildAdvancedSecurityCard(context, isDarkMode),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String text,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors:
              isDarkMode
                  ? [
                    Colors.red.shade900.withValues(alpha: 0.8),
                    Colors.deepPurple.shade900.withValues(alpha: 0.8),
                  ]
                  : [
                    Colors.red.shade700.withValues(alpha: 0.8),
                    Colors.deepPurple.shade700.withValues(alpha: 0.8),
                  ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                isDarkMode
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.red.shade700.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool isDarkMode,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppLockCard(BuildContext context, bool isDarkMode) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              isDarkMode
                  ? Colors.grey.shade800.withValues(alpha: 0.5)
                  : Colors.grey.shade200,
          width: 1,
        ),
      ),
      color: isDarkMode ? Colors.grey.shade900 : Colors.white,
      child: Column(
        children: [
          // Enable App Lock
          Obx(
            () => _buildSwitchTile(
              context: context,
              icon: Icons.lock_outline_rounded,
              iconColor: Colors.red,
              title: 'enable_app_lock'.tr,
              subtitle: 'Secure your app with authentication',
              value: controller.appLock,
              isDarkMode: isDarkMode,
            ),
          ),

          if (controller.appLock.value) ...[
            _buildDivider(context),

            // Lock Method
            _buildSettingTile(
              context: context,
              icon: Icons.fingerprint_rounded,
              iconColor: Colors.orange,
              title: 'lock_method'.tr,
              subtitle: Obx(
                () => Text(
                  _getLockMethodText(),
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              onTap: () => _showLockMethodDialog(context),
              isDarkMode: isDarkMode,
            ),

            _buildDivider(context),

            // Auto-lock Timing
            _buildSettingTile(
              context: context,
              icon: Icons.timer_outlined,
              iconColor: Colors.green,
              title: 'auto_lock_timing'.tr,
              subtitle: Obx(
                () => Text(
                  _getAutoLockTimingText(),
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              onTap: () => _showAutoLockTimingDialog(context),
              isDarkMode: isDarkMode,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrivacyCard(BuildContext context, bool isDarkMode) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              isDarkMode
                  ? Colors.grey.shade800.withValues(alpha: 0.5)
                  : Colors.grey.shade200,
          width: 1,
        ),
      ),
      color: isDarkMode ? Colors.grey.shade900 : Colors.white,
      child: Column(
        children: [
          // Hide Notification Content
          Obx(
            () => _buildSwitchTile(
              context: context,
              icon: Icons.notifications_off_outlined,
              iconColor: Colors.purple,
              title: 'hide_notification_content'.tr,
              subtitle: 'Show only sender name in notifications',
              value: controller.hideNotificationContent,
              isDarkMode: isDarkMode,
            ),
          ),

          _buildDivider(context),

          // Block Remote Images
          Obx(
            () => _buildSwitchTile(
              context: context,
              icon: Icons.image_not_supported_outlined,
              iconColor: Colors.blue,
              title: 'block_remote_images'.tr,
              subtitle: 'Prevent loading of remote images in emails',
              value: controller.blockRemoteImages,
              isDarkMode: isDarkMode,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSecurityCard(BuildContext context, bool isDarkMode) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              isDarkMode
                  ? Colors.grey.shade800.withValues(alpha: 0.5)
                  : Colors.grey.shade200,
          width: 1,
        ),
      ),
      color: isDarkMode ? Colors.grey.shade900 : Colors.white,
      child: Column(
        children: [
          // Spam Filter
          Obx(
            () => _buildSwitchTile(
              context: context,
              icon: Icons.report_outlined,
              iconColor: Colors.amber,
              title: 'enhanced_spam_filter'.tr,
              subtitle: 'Use advanced algorithms to detect spam',
              value: controller.enhancedSpamFilter,
              isDarkMode: isDarkMode,
            ),
          ),

          _buildDivider(context),

          // Clear Data
          _buildSettingTile(
            context: context,
            icon: Icons.delete_outline_rounded,
            iconColor: Colors.red,
            title: 'clear_app_data'.tr,
            subtitle: Text(
              'Delete all cached data and reset preferences',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            onTap: () => _showClearDataDialog(context),
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required RxBool value,
    required bool isDarkMode,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => value.toggle(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),

            Switch.adaptive(
              value: value(),
              activeThumbColor: theme.colorScheme.primary,
              activeTrackColor: theme.colorScheme.primary.withValues(
                alpha: 0.3,
              ),
              inactiveThumbColor:
                  isDarkMode ? Colors.grey.shade400 : Colors.grey.shade50,
              inactiveTrackColor:
                  isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
              onChanged: (val) => value.toggle(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget subtitle,
    Widget? trailing,
    required VoidCallback onTap,
    required bool isDarkMode,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      splashColor: iconColor.withValues(alpha: 0.1),
      highlightColor: iconColor.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  subtitle,
                ],
              ),
            ),

            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final theme = Theme.of(context);

    return Divider(
      height: 1,
      indent: 70,
      color: theme.dividerColor.withValues(alpha: 0.1),
    );
  }

  String _getLockMethodText() {
    switch (controller.lockMethod.value) {
      case 'pin':
        return 'PIN';
      case 'biometric':
        return 'Biometric';
      case 'pattern':
        return 'Pattern';
      default:
        return 'Not set';
    }
  }

  String _getAutoLockTimingText() {
    switch (controller.autoLockTiming.value) {
      case 'immediate':
        return 'Immediately';
      case '1min':
        return 'After 1 minute';
      case '5min':
        return 'After 5 minutes';
      case '15min':
        return 'After 15 minutes';
      case '30min':
        return 'After 30 minutes';
      case '1hour':
        return 'After 1 hour';
      default:
        return 'Not set';
    }
  }

  void _showLockMethodDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
            title: Text(
              'lock_method'.tr,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLockMethodOption(
                  context,
                  icon: Icons.pin_rounded,
                  title: 'PIN',
                  subtitle: 'Secure with a numeric code',
                  value: 'pin',
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 8),
                _buildLockMethodOption(
                  context,
                  icon: Icons.fingerprint_rounded,
                  title: 'Biometric',
                  subtitle: 'Use fingerprint or face recognition',
                  value: 'biometric',
                  isDarkMode: isDarkMode,
                ),
                const SizedBox(height: 8),
                _buildLockMethodOption(
                  context,
                  icon: Icons.pattern_rounded,
                  title: 'Pattern',
                  subtitle: 'Draw a pattern to unlock',
                  value: 'pattern',
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'cancel'.tr,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildLockMethodOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required bool isDarkMode,
  }) {
    final theme = Theme.of(context);

    return Obx(
      () => InkWell(
        onTap: () {
          controller.lockMethod.value = value;
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                controller.lockMethod.value == value
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : isDarkMode
                    ? Colors.grey.shade800.withValues(alpha: 0.5)
                    : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  controller.lockMethod.value == value
                      ? theme.colorScheme.primary
                      : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      controller.lockMethod.value == value
                          ? theme.colorScheme.primary.withValues(alpha: 0.2)
                          : isDarkMode
                          ? Colors.grey.shade700
                          : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color:
                      controller.lockMethod.value == value
                          ? theme.colorScheme.primary
                          : isDarkMode
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color:
                            controller.lockMethod.value == value
                                ? theme.colorScheme.primary
                                : isDarkMode
                                ? Colors.white
                                : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (controller.lockMethod.value == value)
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAutoLockTimingDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
            title: Text(
              'auto_lock_timing'.tr,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAutoLockOption(
                  context,
                  title: 'Immediately',
                  value: 'immediate',
                  isDarkMode: isDarkMode,
                ),
                _buildAutoLockOption(
                  context,
                  title: 'After 1 minute',
                  value: '1min',
                  isDarkMode: isDarkMode,
                ),
                _buildAutoLockOption(
                  context,
                  title: 'After 5 minutes',
                  value: '5min',
                  isDarkMode: isDarkMode,
                ),
                _buildAutoLockOption(
                  context,
                  title: 'After 15 minutes',
                  value: '15min',
                  isDarkMode: isDarkMode,
                ),
                _buildAutoLockOption(
                  context,
                  title: 'After 30 minutes',
                  value: '30min',
                  isDarkMode: isDarkMode,
                ),
                _buildAutoLockOption(
                  context,
                  title: 'After 1 hour',
                  value: '1hour',
                  isDarkMode: isDarkMode,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'cancel'.tr,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildAutoLockOption(
    BuildContext context, {
    required String title,
    required String value,
    required bool isDarkMode,
  }) {
    final theme = Theme.of(context);

    return Obx(
      () => InkWell(
        onTap: () {
          controller.autoLockTiming.value = value;
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color:
                controller.autoLockTiming.value == value
                    ? theme.colorScheme.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  controller.autoLockTiming.value == value
                      ? theme.colorScheme.primary
                      : isDarkMode
                      ? Colors.grey.shade700
                      : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      controller.autoLockTiming.value == value
                          ? FontWeight.w500
                          : FontWeight.normal,
                  color:
                      controller.autoLockTiming.value == value
                          ? theme.colorScheme.primary
                          : isDarkMode
                          ? Colors.white
                          : Colors.black87,
                ),
              ),
              if (controller.autoLockTiming.value == value)
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
            title: Text(
              'clear_app_data'.tr,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            content: Text(
              'This will delete all cached data and reset your preferences. This action cannot be undone.',
              style: TextStyle(
                fontSize: 15,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'cancel'.tr,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Clear data logic
                  Get.find<AuthController>().clearStorage();
                  Get.snackbar(
                    'Success',
                    'All data has been cleared',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                    margin: const EdgeInsets.all(16),
                    borderRadius: 10,
                    duration: const Duration(seconds: 3),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text('clear'.tr),
              ),
            ],
          ),
    );
  }
}
