import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import '../../app/controllers/settings_controller.dart';
import 'pages/language_page.dart';
import 'pages/signature_page.dart';
import 'pages/swipe_gesture.dart';
import 'pages/security_page.dart';

class SettingsView extends GetView<SettingController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'settings'.tr,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.primary,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Profile section
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      controller.accountName().isNotEmpty
                          ? controller.accountName()[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Obx(() => Text(
                          controller.accountName(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        )),
                        const SizedBox(height: 4),
                        // Text(
                        //   Get.find<MailBoxController>().account.email,
                        //   style: TextStyle(
                        //     fontSize: 14,
                        //     color: theme.colorScheme.onSurface.withOpacity(0.7),
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Section headers
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
              child: Text(
                'preferences'.tr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),

            // Settings cards
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.dividerColor.withOpacity(0.1),
                ),
              ),
              child: Column(
                children: [
                  // Language setting
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.language, color: Colors.blue),
                    ),
                    title: Text('language'.tr),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Obx(() => Text(
                          controller.language() == 'ar' ? 'arabic'.tr : 'english'.tr,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        )),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: theme.colorScheme.onSurface.withOpacity(0.3),
                        ),
                      ],
                    ),
                    onTap: () => Get.to(() => const LanguagePage()),
                  ),

                  // Read receipts setting
                  Divider(height: 1, indent: 70, color: theme.dividerColor.withOpacity(0.1)),

                  Obx(() => ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long, color: Colors.green),
                    ),
                    title: Text('readreceipt'.tr),
                    trailing: Switch.adaptive(
                      value: controller.readReceipts(),
                      activeColor: theme.colorScheme.primary,
                      onChanged: (value) => controller.readReceipts.toggle(),
                    ),
                    onTap: () => controller.readReceipts.toggle(),
                  )),
                ],
              ),
            ),

            // Customization section
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
              child: Text(
                'customization'.tr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),

            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.dividerColor.withOpacity(0.1),
                ),
              ),
              child: Column(
                children: [
                  // Swipe gestures
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.swipe, color: Colors.orange),
                    ),
                    title: Text('swipe_gestures'.tr),
                    subtitle: Text(
                      'set_your_swipe_preferences'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    onTap: () => Get.to(() => SwipGestureSetting()),
                  ),

                  Divider(height: 1, indent: 70, color: theme.dividerColor.withOpacity(0.1)),

                  // Signature
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_note, color: Colors.purple),
                    ),
                    title: Text('signature'.tr),
                    subtitle: Text(
                      'set_your_sig'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    onTap: () => Get.to(() => const SignaturePage()),
                  ),
                ],
              ),
            ),

            // Security section
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
              child: Text(
                'security'.tr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),

            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: theme.dividerColor.withOpacity(0.1),
                ),
              ),
              child: Column(
                children: [
                  // Security settings
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.security, color: Colors.red),
                    ),
                    title: Text('security'.tr),
                    trailing: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    onTap: () => Get.to(() => const SecurityPage()),
                  ),

                  Divider(height: 1, indent: 70, color: theme.dividerColor.withOpacity(0.1)),

                  // Logout
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.logout, color: Colors.grey),
                    ),
                    title: Text('logout'.tr),
                    onTap: () => Get.find<MailBoxController>().logout(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // App version
            Center(
              child: Text(
                'Version 1.0.0',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
