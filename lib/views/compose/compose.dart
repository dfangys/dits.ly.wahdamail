import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';
import 'package:wahda_bank/views/compose/widgets/compose_view.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';

class ComposeScreen extends StatelessWidget {
  ComposeScreen({super.key});
  final composeFormKey = GlobalKey<FormState>();
  final controller = Get.put(ComposeController());
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Get.back();
          },
          icon: SvgPicture.asset(WImages.backErrow),
        ),
        title: const Text(
          "Compose",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {
              showCupertinoModalPopup(
                context: context,
                builder: (context) => CupertinoActionSheet(
                  title: const Text('Attach File'),
                  actions: [
                    CupertinoActionSheetAction(
                      onPressed: () {},
                      child: const Text('From Files'),
                    ),
                    CupertinoActionSheetAction(
                      onPressed: () {},
                      child: const Text('From Gallery'),
                    ),
                  ],
                  cancelButton: CupertinoActionSheetAction(
                    onPressed: () {
                      Get.back();
                    },
                    child: const Text('Cancel'),
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
                  title: const Text('More Options'),
                  actions: [
                    CupertinoActionSheetAction(
                      onPressed: () {},
                      child: const Text('Save as Draft'),
                    ),
                    CupertinoActionSheetAction(
                      onPressed: () {},
                      child: const Text('Request Read Receipt'),
                    ),
                    CupertinoActionSheetAction(
                      onPressed: () {},
                      child: const Text('Convert to plain text'),
                    ),
                  ],
                  cancelButton: CupertinoActionSheetAction(
                    onPressed: () {
                      Get.back();
                    },
                    child: const Text('Cancel'),
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
