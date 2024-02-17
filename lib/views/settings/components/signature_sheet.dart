import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import '../../../app/controllers/settings_controller.dart';

class SignatureSheet extends GetView<SettingController> {
  SignatureSheet({super.key});
  final htmlController = HtmlEditorController();
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Text("Signature"),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          controller.signature("");
                          Get.back();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: () async {
                          controller.signature(await htmlController.getText());
                          Get.back();
                        },
                      ),
                    ],
                  )
                ],
              ),
              const Divider(),
              HtmlEditor(
                controller: htmlController,
                htmlToolbarOptions:
                    const HtmlToolbarOptions(defaultToolbarButtons: [
                  FontButtons(),
                  ColorButtons(),
                  ListButtons(),
                ]),
                htmlEditorOptions: HtmlEditorOptions(
                  hint: "Your message here...",
                  initialText: controller.signature(),
                ),
                otherOptions: const OtherOptions(
                  height: 400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
