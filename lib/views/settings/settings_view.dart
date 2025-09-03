import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../app/controllers/settings_controller.dart';
import '../../app/controllers/auth_controller.dart';
import 'pages/language_page.dart';
import 'pages/signature_page.dart';
import 'pages/swipe_gesture.dart';
import 'pages/security_page.dart';
import 'components/profile_details_sheet.dart';

class SettingsView extends GetView<SettingController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Modern app bar with blur effect
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor:
                isDarkMode
                    ? Colors.black.withValues(alpha: 0.7)
                    : Colors.white.withValues(alpha: 0.9),
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: FlexibleSpaceBar(
                  title: Text(
                    'settings'.tr,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color:
                          isDarkMode ? Colors.white : theme.colorScheme.primary,
                      fontSize: 22,
                    ),
                  ),
                  centerTitle: true,
                ),
              ),
            ),
            actions: [
              // Theme toggle button
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: IconButton(
                  icon: Icon(
                    isDarkMode
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    color: isDarkMode ? Colors.amber : Colors.indigo,
                  ),
                  onPressed: () {
                    // Toggle theme logic would go here
                    Get.changeThemeMode(
                      Get.isDarkMode ? ThemeMode.light : ThemeMode.dark,
                    );
                  },
                  tooltip: isDarkMode ? 'Light Mode' : 'Dark Mode',
                ),
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(height: 16),

                  // Enhanced Profile Section with email fix
                  _buildProfileSection(context, isDarkMode),

                  const SizedBox(height: 24),

                  // Preferences Section
                  _buildSectionHeader(
                    context,
                    'preferences'.tr,
                    Icons.tune_rounded,
                  ),

                  const SizedBox(height: 12),

                  _buildPreferencesCard(context, isDarkMode),

                  const SizedBox(height: 24),

                  // Customization Section
                  _buildSectionHeader(
                    context,
                    'customization'.tr,
                    Icons.palette_rounded,
                  ),

                  const SizedBox(height: 12),

                  _buildCustomizationCard(context, isDarkMode),

                  const SizedBox(height: 24),

                  // Security Section
                  _buildSectionHeader(
                    context,
                    'security'.tr,
                    Icons.shield_rounded,
                  ),

                  const SizedBox(height: 12),

                  _buildSecurityCard(context, isDarkMode),

                  const SizedBox(height: 32),

                  // App version with animation
                  Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Version 1.0.0',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced Profile Section with email loading fix
  Widget _buildProfileSection(BuildContext context, bool isDarkMode) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        // Show profile details sheet
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const ProfileDetailsSheet(),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors:
                isDarkMode
                    ? [Colors.indigo.shade800, Colors.purple.shade900]
                    : [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withValues(
                        blue: (theme.colorScheme.primary.b + (40 / 255.0))
                            .clamp(0.0, 1.0),
                      ),
                    ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color:
                  isDarkMode
                      ? Colors.black.withValues(alpha: 0.3)
                      : theme.colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar with animation
            TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 500),
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Hero(
                tag: 'profile_avatar',
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor:
                        isDarkMode
                            ? Colors.indigo.shade700
                            : theme.colorScheme.primary,
                    child: Obx(
                      () => Text(
                        controller.accountName().isNotEmpty
                            ? controller.accountName()[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 20),

            // User info with staggered animation
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name with animation
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 600),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(20 * (1 - value), 0),
                          child: child,
                        ),
                      );
                    },
                    child: Obx(
                      () => Text(
                        controller.accountName(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Email with animation - Fixed to properly load email
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(20 * (1 - value), 0),
                          child: child,
                        ),
                      );
                    },
                    child: Obx(() {
                      final email =
                          controller.userEmail().isNotEmpty
                              ? controller.userEmail()
                              : (Get.find<SettingController>().box
                                      .read('email')
                                      ?.toString() ??
                                  '');
                      return Text(
                        email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    }),
                  ),

                  const SizedBox(height: 12),
                ],
              ),
            ),

            // Chevron indicator
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.white.withValues(alpha: 0.7),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // Modern section header with icon
  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final theme = Theme.of(context);

    return Row(
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
    );
  }

  // Preferences card with modern design
  Widget _buildPreferencesCard(BuildContext context, bool isDarkMode) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
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
          // Language setting
          _buildSettingTile(
            context: context,
            icon: Icons.language_rounded,
            iconColor: Colors.blue,
            title: 'language'.tr,
            subtitle: Obx(
              () => Text(
                controller.language() == 'ar' ? 'arabic'.tr : 'english'.tr,
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
            onTap: () => Get.to(() => const LanguagePage()),
            isDarkMode: isDarkMode,
          ),

          // Divider with animation
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, child) {
              return Opacity(opacity: value, child: child);
            },
            child: Divider(
              height: 1,
              indent: 70,
              color: theme.dividerColor.withValues(alpha: 0.1),
            ),
          ),

          // Read receipts setting
          Obx(
            () => _buildSettingTile(
              context: context,
              icon: Icons.receipt_long_rounded,
              iconColor: Colors.green,
              title: 'readreceipt'.tr,
              trailing: Switch.adaptive(
                value: controller.readReceipts(),
                activeThumbColor: theme.colorScheme.primary,
                activeTrackColor: theme.colorScheme.primary.withValues(
                  alpha: 0.3,
                ),
                inactiveThumbColor:
                    isDarkMode ? Colors.grey.shade400 : Colors.grey.shade50,
                inactiveTrackColor:
                    isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                onChanged: (value) => controller.readReceipts.toggle(),
              ),
              onTap: () => controller.readReceipts.toggle(),
              isDarkMode: isDarkMode,
            ),
          ),
        ],
      ),
    );
  }

  // Customization card with modern design
  Widget _buildCustomizationCard(BuildContext context, bool isDarkMode) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
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
          // Swipe gestures
          _buildSettingTile(
            context: context,
            icon: Icons.swipe_rounded,
            iconColor: Colors.orange,
            title: 'swipe_gestures'.tr,
            subtitle: Text(
              'set_your_swipe_preferences'.tr,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            onTap: () => Get.to(() => SwipGestureSetting()),
            isDarkMode: isDarkMode,
          ),

          // Divider with animation
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, child) {
              return Opacity(opacity: value, child: child);
            },
            child: Divider(
              height: 1,
              indent: 70,
              color: theme.dividerColor.withValues(alpha: 0.1),
            ),
          ),

          // Signature
          _buildSettingTile(
            context: context,
            icon: Icons.edit_note_rounded,
            iconColor: Colors.purple,
            title: 'signature'.tr,
            subtitle: Text(
              'set_your_sig'.tr,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            onTap: () => Get.to(() => const SignaturePage()),
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  // Security card with modern design
  Widget _buildSecurityCard(BuildContext context, bool isDarkMode) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
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
          // Security settings
          _buildSettingTile(
            context: context,
            icon: Icons.security_rounded,
            iconColor: Colors.red,
            title: 'security'.tr,
            trailing: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            onTap: () => Get.to(() => const SecurityPage()),
            isDarkMode: isDarkMode,
          ),

          // Divider with animation
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, child) {
              return Opacity(opacity: value, child: child);
            },
            child: Divider(
              height: 1,
              indent: 70,
              color: theme.dividerColor.withValues(alpha: 0.1),
            ),
          ),

          // Logout
          _buildSettingTile(
            context: context,
            icon: Icons.logout_rounded,
            iconColor: Colors.grey,
            title: 'logout'.tr,
            onTap: () {
              // Show confirmation dialog with modern design
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: Text('logout_confirmation'.tr),
                      content: Text('logout_confirmation_message'.tr),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'cancel'.tr,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Get.find<AuthController>().logout();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text('logout'.tr),
                        ),
                      ],
                    ),
              );
            },
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  // Modern setting tile with hover effect
  Widget _buildSettingTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    Widget? subtitle,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            // Icon with container
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),

            const SizedBox(width: 16),

            // Title and subtitle
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
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    subtitle,
                  ],
                ],
              ),
            ),

            // Trailing widget
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}
