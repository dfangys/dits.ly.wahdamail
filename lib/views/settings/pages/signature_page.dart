import 'dart:io';

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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'signature'.tr,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.primary,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with explanation
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.edit_note,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Your signature will be added to the end of your emails',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Signature options section
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Text(
              'signature_options'.tr,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),

          // Signature options card
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
                // Reply signature option
                Obx(() => SwitchListTile(
                  title: Text('reply'.tr),
                  subtitle: Text(
                    'Include signature when replying',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  value: controller.signatureReply(),
                  activeColor: theme.colorScheme.primary,
                  onChanged: (value) => controller.signatureReply(value),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.reply, color: Colors.blue),
                  ),
                )),

                Divider(height: 1, indent: 70, color: theme.dividerColor.withOpacity(0.1)),

                // Forward signature option
                Obx(() => SwitchListTile(
                  title: Text('forward'.tr),
                  subtitle: Text(
                    'Include signature when forwarding',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  value: controller.signatureForward(),
                  activeColor: theme.colorScheme.primary,
                  onChanged: (value) => controller.signatureForward(value),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.forward, color: Colors.green),
                  ),
                )),

                Divider(height: 1, indent: 70, color: theme.dividerColor.withOpacity(0.1)),

                // New message signature option
                Obx(() => SwitchListTile(
                  title: Text('new_message'.tr),
                  subtitle: Text(
                    'Include signature in new messages',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  value: controller.signatureNewMessage(),
                  activeColor: theme.colorScheme.primary,
                  onChanged: (value) => controller.signatureNewMessage(value),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit, color: Colors.purple),
                  ),
                )),
              ],
            ),
          ),

          // Account name section
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
            child: Text(
              'account_details'.tr,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),

          // Account name card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.dividerColor.withOpacity(0.1),
              ),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.person, color: Colors.orange),
              ),
              title: const Text('Account Name'),
              subtitle: Obx(() => Text(
                controller.accountName(),
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              )),
              trailing: Icon(
                Icons.edit,
                size: 20,
                color: theme.colorScheme.primary,
              ),
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
            ),
          ),

          // Signature content section
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "signature".tr,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text('edit'.tr),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
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
                ),
              ],
            ),
          ),

          // Signature preview
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
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
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No signature set',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              )
                  : SingleChildScrollView(
                child: HtmlWidget(
                  controller.signature(),
                  textStyle: const TextStyle(fontSize: 14),
                ),
              ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
