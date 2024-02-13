import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/controllers/settings_controller.dart';
import 'pages/language_page.dart';
import 'pages/security_page.dart';
import 'pages/signature_page.dart';
import 'pages/swipe_gesture.dart';

class SettingsView extends GetView<SettingController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            ListTile(
              title: Text('language'.tr),
              trailing: Obx(
                () => Text(
                  controller.language() == 'ar' ? 'arabic'.tr : 'english'.tr,
                ),
              ),
              onTap: () {
                Get.to(() => const LanguagePage());
              },
            ),
            Divider(),
            ListTile(
              title: Text('Read receipts'),
              trailing: Text('Off'),
              onTap: () {},
            ),
            Divider(),
            ListTile(
              title: const Text('Security'),
              trailing: const Text('Off'),
              onTap: () {
                Get.to(() => const SecurityPage());
              },
            ),
            ListTile(
              title: Text('Swipe Gestures '),
              trailing: Text('Set your swipe preferences'),
              onTap: () {
                Get.to(() => SwipGestureSetting());
              },
            ),
            ListTile(
              title: Text('Signature'),
              trailing: Text('Set your signature'),
              onTap: () {
                Get.to(() => SignaturePage());
              },
            ),
            ListTile(
              title: Text('Logout'),
              trailing: Icon(Icons.logout),
            ),
          ],
        ),
      ),
    );
  }
}
