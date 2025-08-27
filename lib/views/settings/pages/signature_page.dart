import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/settings/components/signature_sheet.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import '../../../app/controllers/settings_controller.dart';
import '../components/account_name.dart';

class SignaturePage extends GetView<SettingController> {
  const SignaturePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'signature'.tr,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDarkMode ? Colors.black.withValues(alpha : 0.7) : Colors.white.withValues(alpha : 0.9),
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
              icon: Icons.edit_note,
              text: 'Your signature will be added to the end of your emails',
              isDarkMode: isDarkMode,
            ),

            // Signature options section
            _buildSectionHeader(
              context,
              title: 'signature_options'.tr,
              icon: Icons.settings_rounded,
              isDarkMode: isDarkMode,
            ),

            // Signature options card
            _buildOptionsCard(context, isDarkMode),

            // Account name section
            _buildSectionHeader(
              context,
              title: 'account_details'.tr,
              icon: Icons.person_rounded,
              isDarkMode: isDarkMode,
            ),

            // Account name card
            _buildAccountNameCard(context, isDarkMode),

            // Signature content section
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle(context, "signature".tr, isDarkMode),
                  _buildEditButton(context, isDarkMode),
                ],
              ),
            ),

            // Signature preview
            _buildSignaturePreview(context, isDarkMode),
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
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [Colors.indigo.shade800.withValues(alpha : 0.8), Colors.purple.shade900.withValues(alpha : 0.8)]
              : [
                theme.colorScheme.primary.withValues(alpha : 0.8),
                theme.colorScheme.primary.withValues(
                  blue: (theme.colorScheme.primary.b + (40 / 255.0)).clamp(0.0, 1.0),
                  alpha: 0.8,
                )
              ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha : 0.2)
                : theme.colorScheme.primary.withValues(alpha : 0.2),
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
              color: Colors.white.withValues(alpha : 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
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
              color: theme.colorScheme.primary.withValues(alpha : 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: theme.colorScheme.primary,
            ),
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

  Widget _buildSectionTitle(BuildContext context, String title, bool isDarkMode) {
    final theme = Theme.of(context);

    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildOptionsCard(BuildContext context, bool isDarkMode) {

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDarkMode
              ? Colors.grey.shade800.withValues(alpha : 0.5)
              : Colors.grey.shade200,
          width: 1,
        ),
      ),
      color: isDarkMode ? Colors.grey.shade900 : Colors.white,
      child: Column(
        children: [
          // Reply signature option
          _buildSwitchTile(
            context: context,
            icon: Icons.reply_rounded,
            iconColor: Colors.blue,
            title: 'reply'.tr,
            subtitle: 'Include signature when replying',
            value: controller.signatureReply,
            isDarkMode: isDarkMode,
          ),

          _buildDivider(context),

          // Forward signature option
          _buildSwitchTile(
            context: context,
            icon: Icons.forward_rounded,
            iconColor: Colors.green,
            title: 'forward'.tr,
            subtitle: 'Include signature when forwarding',
            value: controller.signatureForward,
            isDarkMode: isDarkMode,
          ),

          _buildDivider(context),

          // New message signature option
          _buildSwitchTile(
            context: context,
            icon: Icons.edit_rounded,
            iconColor: Colors.purple,
            title: 'new_message'.tr,
            subtitle: 'Include signature in new messages',
            value: controller.signatureNewMessage,
            isDarkMode: isDarkMode,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountNameCard(BuildContext context, bool isDarkMode) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDarkMode
              ? Colors.grey.shade800.withValues(alpha : 0.5)
              : Colors.grey.shade200,
          width: 1,
        ),
      ),
      color: isDarkMode ? Colors.grey.shade900 : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (Platform.isAndroid) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => AccountNameSheet(),
            );
          } else {
            showCupertinoModalPopup(
              context: context,
              builder: (context) => AccountNameSheet(),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.person_rounded, color: Colors.orange, size: 22),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Account Name',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Obx(() => Text(
                      controller.accountName(),
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(alpha : 0.6),
                      ),
                    )),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha : 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.edit,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditButton(BuildContext context, bool isDarkMode) {
    final theme = Theme.of(context);

    return ElevatedButton.icon(
      icon: const Icon(Icons.edit, size: 16),
      label: Text('edit'.tr),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      onPressed: () {
        if (Platform.isAndroid) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const SignatureSheet(),
          );
        } else {
          showCupertinoModalPopup(
            context: context,
            builder: (context) => const SignatureSheet(),
          );
        }
      },
    );
  }

  Widget _buildSignaturePreview(BuildContext context, bool isDarkMode) {
    final theme = Theme.of(context);

    return Container(
      height: 300,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.grey.shade700
              : Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Obx(() => controller.signature().isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.edit_note,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha : 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No signature set',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha : 0.5),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the edit button to create your signature',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha : 0.4),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: HtmlWidget(
          controller.signature(),
          textStyle: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
      ),
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

    return Obx(() => InkWell(
      onTap: () => value.toggle(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha : 0.1),
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
                      color: theme.colorScheme.onSurface.withValues(alpha : 0.6),
                    ),
                  ),
                ],
              ),
            ),

            Switch.adaptive(
              value: value(),
              activeTrackColor: theme.colorScheme.primary.withValues(alpha : 0.3),
              inactiveThumbColor: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade50,
              inactiveTrackColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
              onChanged: (val) => value.toggle(),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildDivider(BuildContext context) {
    final theme = Theme.of(context);

    return Divider(
      height: 1,
      indent: 70,
      color: theme.dividerColor.withValues(alpha : 0.1),
    );
  }
}
