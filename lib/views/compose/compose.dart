import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';
import 'package:wahda_bank/views/compose/widgets/compose_view.dart';

class ComposeScreen extends StatelessWidget {
  ComposeScreen({super.key});
  final composeFormKey = GlobalKey<FormState>();
  final controller = Get.put(ComposeController());
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        // title: Text(
        //   "compose".tr,
        //   style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        // ),
        actions: [
          IconButton(
            onPressed: controller.sendEmail,
            icon: const Icon(Icons.send_outlined),
          ),
          IconButton(
            onPressed: () {
              showCupertinoModalPopup(
                context: context,
                builder: (context) => CupertinoActionSheet(
                  title: Text('attach_file'.tr),
                  actions: [
                    CupertinoActionSheetAction(
                      onPressed: () {
                        controller.pickFiles();
                      },
                      child: Text('from_files'.tr),
                    ),
                    CupertinoActionSheetAction(
                      onPressed: () {
                        controller.pickImage();
                      },
                      child: Text('from_gallery'.tr),
                    ),
                  ],
                  cancelButton: CupertinoActionSheetAction(
                    onPressed: () {
                      Get.back();
                    },
                    child: Text('cancel'.tr),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.attach_file_outlined),
          ),
          IconButton(
            onPressed: () {
              showCupertinoModalPopup(
                context: context,
                builder: (context) => CupertinoActionSheet(
                  title: Text('more_options'.tr),
                  actions: [
                    CupertinoActionSheetAction(
                      onPressed: () {},
                      child: Text('save_as_draft'.tr),
                    ),
                    CupertinoActionSheetAction(
                      onPressed: () {},
                      child: Text('request_read_receipt'.tr),
                    ),
                    CupertinoActionSheetAction(
                      onPressed: () {},
                      child: Text('convert_to_plain_text'.tr),
                    ),
                  ],
                  cancelButton: CupertinoActionSheetAction(
                    onPressed: () {
                      Get.back();
                    },
                    child: Text('cancel'.tr),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.more_vert_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Form(
          key: composeFormKey,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: WComposeView(),
          ),
        ),
      ),
    );
  }
}
