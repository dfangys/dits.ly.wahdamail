import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';
import 'package:wahda_bank/views/compose/widgets/compose_view.dart';

import '../../utills/funtions.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final composeFormKey = GlobalKey<FormState>();
  final controller = Get.put(ComposeController());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (Get.locale != null && Get.locale!.languageCode == 'ar') {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: controller.canPop(),
      onPopInvoked: (didPop) async {
        if (!didPop) {
          var isConfirmed = await confirmDraft(context);
          printInfo(info: isConfirmed.toString());
          if (isConfirmed) {
            await controller.saveAsDraft();
          }
          controller.canPop(true);
          if (mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
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
                          Get.back();
                          controller.pickFiles();
                        },
                        child: Text('from_files'.tr),
                      ),
                      CupertinoActionSheetAction(
                        onPressed: () {
                          Get.back();
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
                        onPressed: () {
                          Get.back();
                          controller.saveAsDraft();
                        },
                        child: Text('save_as_draft'.tr),
                      ),
                      CupertinoActionSheetAction(
                        onPressed: () {
                          Get.back();
                          Get.find<SettingController>().readReceipts.toggle();
                        },
                        child: Text('request_read_receipt'.tr),
                      ),
                      CupertinoActionSheetAction(
                        onPressed: () {
                          Get.back();
                          controller.togglePlainHtml();
                        },
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
      ),
    );
  }
}
