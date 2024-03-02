import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import '../../../app/controllers/settings_controller.dart';

class SignatureSheet extends StatefulWidget {
  const SignatureSheet({super.key});

  @override
  State<SignatureSheet> createState() => _SignatureSheetState();
}

class _SignatureSheetState extends State<SignatureSheet> {
  final htmlController = HtmlEditorController();
  final controller = Get.find<SettingController>();
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
          child: SingleChildScrollView(
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
                          icon: Obx(
                            () => Icon(
                              controller.signatureCodeView()
                                  ? Icons.code_off
                                  : Icons.code,
                            ),
                          ),
                          onPressed: () {
                            controller.signatureCodeView.toggle();
                            htmlController.toggleCodeView();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.check),
                          onPressed: () async {
                            controller
                                .signature(await htmlController.getText());
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
                  htmlToolbarOptions: const HtmlToolbarOptions(
                    defaultToolbarButtons: [
                      FontButtons(),
                      ColorButtons(),
                      ListButtons(),
                    ],
                  ),
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
      ),
    );
  }
}
