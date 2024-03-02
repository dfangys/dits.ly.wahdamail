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
    return Scaffold(
      appBar: AppBar(
        title: Text('signature'.tr),
      ),
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          children: [
            ListTile(
              leading: Obx(
                () => Icon(
                  Icons.check_circle,
                  color:
                      controller.signatureReply() ? Colors.green : Colors.grey,
                ),
              ),
              title: Text('reply'.tr),
              onTap: () {
                controller.signatureReply(!controller.signatureReply());
              },
            ),
            ListTile(
              leading: Obx(
                () => Icon(
                  Icons.check_circle,
                  color: controller.signatureForward()
                      ? Colors.green
                      : Colors.grey,
                ),
              ),
              title: Text('forward'.tr),
              onTap: () {
                controller.signatureForward(!controller.signatureForward());
              },
            ),
            ListTile(
              leading: Obx(
                () => Icon(
                  Icons.check_circle,
                  color: controller.signatureNewMessage()
                      ? Colors.green
                      : Colors.grey,
                ),
              ),
              title: Text('new_message'.tr),
              onTap: () {
                controller
                    .signatureNewMessage(!controller.signatureNewMessage());
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.abc),
              title: const Text('Account Name'),
              subtitle: Obx(() => Text(controller.accountName())),
              onTap: () {
                if (Platform.isAndroid) {
                  showModalBottomSheet(
                    context: context,
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
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("signature".tr),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    if (Platform.isAndroid) {
                      showCupertinoModalPopup(
                        context: context,
                        builder: (context) => const SignatureSheet(),
                      );
                    } else {
                      showModalBottomSheet(
                        context: context,
                        builder: (context) => const SignatureSheet(),
                      );
                    }
                  },
                )
              ],
            ),
            Expanded(
              child: Obx(() => HtmlWidget(
                    controller.signature(),
                  )),
            )
          ],
        ),
      ),
    );
  }
}
