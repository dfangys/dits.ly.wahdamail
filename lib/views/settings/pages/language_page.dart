import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';

class LanguagePage extends GetView<SettingController> {
  const LanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Language'),
      ),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: Obx(
              () => Icon(
                Icons.check_circle_sharp,
                color:
                    controller.language() == 'en' ? Colors.green : Colors.grey,
              ),
            ),
            title: const Text('English'),
            onTap: () {
              controller.language('en');
              Get.updateLocale(const Locale('en'));
            },
          ),
          ListTile(
            leading: Obx(
              () => Icon(
                Icons.check_circle_sharp,
                color:
                    controller.language() == 'ar' ? Colors.green : Colors.grey,
              ),
            ),
            title: const Text('Arabic'),
            onTap: () {
              controller.language('ar');
              Get.updateLocale(const Locale('ar'));
            },
          ),
        ],
      ),
    );
  }
}
