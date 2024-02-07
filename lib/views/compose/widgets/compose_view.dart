import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
import 'package:wahda_bank/views/authantication/screens/login/widgets/rounded_button.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';
import 'package:wahda_bank/views/compose/widgets/text_field.dart';

// ignore: must_be_immutable
class WComposeView extends StatelessWidget {
  WComposeView({
    super.key,
  });

  RoundedLoadingButtonController btnController =
      RoundedLoadingButtonController();
  final HtmlEditorController htmlController = HtmlEditorController();

  final controller = Get.find<ComposeController>();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              initialValue: "info@distly.com",
              readOnly: true,
              decoration: const InputDecoration(
                labelText: "From",
                hintText: "Mr. Abc <info@distly.com>",
              ),
            ),
            Obx(
              () => ToEmailsChipsField(
                title: "To",
                emails: controller.toList.toList(),
                onDelete: (int i) {
                  controller.removeFromToList(i);
                },
                onInsert: (MailAddress address) {
                  controller.addTo(address);
                },
                ccBccWidget: IconButton(
                  onPressed: () {
                    controller.isCcAndBccVisible.toggle();
                  },
                  icon: Icon(
                    controller.isCcAndBccVisible()
                        ? Icons.closed_caption_off_sharp
                        : Icons.closed_caption_disabled,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
            const Divider(color: Colors.grey, thickness: 0.5, height: 0.5),
          ],
        ),
        const SizedBox(height: 10),
        Obx(
          () => AnimatedCrossFade(
            crossFadeState: controller.isCcAndBccVisible()
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                ToEmailsChipsField(
                  title: "CC",
                  emails: controller.cclist.toList(),
                  onDelete: (int i) {
                    controller.removeFromCcList(i);
                  },
                  onInsert: (MailAddress address) {
                    controller.addToCC(address);
                  },
                ),
                const Divider(color: Colors.grey, thickness: 0.5, height: 0.5),
                ToEmailsChipsField(
                  title: "Bcc",
                  emails: controller.bcclist.toList(),
                  onDelete: (int i) {
                    controller.removeFromBccList(i);
                  },
                  onInsert: (MailAddress add) {
                    controller.addToBcc(add);
                  },
                ),
                const Divider(color: Colors.grey, thickness: 0.5, height: 0.5),
              ],
            ),
            secondChild: const SizedBox(),
            duration: const Duration(milliseconds: 300),
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          decoration: const InputDecoration(
            labelText: "Subject",
          ),
        ),
        const Divider(color: Colors.grey, thickness: 0.5, height: 0.5),
        HtmlEditor(
          controller: htmlController,
          htmlToolbarOptions: const HtmlToolbarOptions(defaultToolbarButtons: [
            FontButtons(),
            ColorButtons(),
            ListButtons(),
          ]),
          htmlEditorOptions: const HtmlEditorOptions(
            hint: "Your message here...",
          ),
          otherOptions: const OtherOptions(
            height: 400,
          ),
          callbacks: Callbacks(
            onInit: () {},
            onChangeCodeview: (p0) {
              if (kDebugMode) {
                print(p0);
              }
            },
          ),
        ),
        WRoundedButton(
          controller: btnController,
          onPress: () {},
          text: 'Send',
        )
      ],
    );
  }
}
