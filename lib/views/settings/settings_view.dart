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
        title: Text('settings'.tr),
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
            const Divider(),
            ListTile(
              title: Text('readreceipt'.tr),
              trailing: Text('Off'.tr),
              onTap: () {},
            ),
            const Divider(),
            ListTile(
              title: Text('security'.tr),
              trailing: Text('Off'.tr),
              onTap: () {
                Get.to(() => const SecurityPage());
              },
            ),
            const Divider(),
            ListTile(
              title: Text('swipe_gestures'.tr),
              trailing: Text('set_your_swipe_preferences'.tr),
              onTap: () {
                Get.to(() => SwipGestureSetting());
              },
            ),
            const Divider(),
            ListTile(
              title: Text('signature'.tr),
              trailing: Text('set_your_sig'.tr),
              onTap: () {
                Get.to(() => const SignaturePage());
              },
            ),
            const Divider(),
            ListTile(
              title: Text('logout'.tr),
              trailing: const Icon(Icons.logout),
            ),
          ],
        ),
      ),
    );
  }
}
