import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';
import 'package:wahda_bank/views/compose/widgets/text_field.dart';

class WComposeView extends StatelessWidget {
  WComposeView({
    super.key,
  });

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
              controller: controller.fromController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: "from".tr,
              ),
              style: const TextStyle(fontSize: 14),
            ),
            Obx(
                  () => ToEmailsChipsField(
                title: "to".tr,
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
                  title: "CC".tr,
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
                  title: "bcc".tr,
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
          controller: controller.subjectController,
          decoration: InputDecoration(
            labelText: "subject".tr,
          ),
        ),
        const Divider(color: Colors.grey, thickness: 0.5, height: 0.5),
        Obx(
              () => ListView.builder(
            shrinkWrap: true,
            itemCount: controller.attachments.length,
            itemBuilder: (context, index) {
              return ListTile(
                dense: true,
                title: Text(controller.attachments[index].path.split('/').last),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    controller.attachments.removeAt(index);
                  },
                ),
              );
            },
          ),
        ),
        Obx(
              () => AnimatedCrossFade(
            firstChild: HtmlEditor(
              controller: controller.htmlController,
              htmlToolbarOptions: const HtmlToolbarOptions(
                renderSeparatorWidget: true,
                defaultToolbarButtons: [
                  FontButtons(),
                  ColorButtons(),
                  ListButtons(),
                  ParagraphButtons(
                    caseConverter: false,
                    textDirection: true,
                  ),
                ],
              ),
              htmlEditorOptions: HtmlEditorOptions(
                hint: "Your message here...",
                initialText: controller.bodyPart,
              ),
              otherOptions: const OtherOptions(
                height: 400,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                ),
              ),
            ),
            secondChild: Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                controller: controller.plainTextController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: "Your message here...",
                ),
              ),
            ),
            crossFadeState: controller.isHtml.isTrue
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
          ),
        ),
        Center(
          child: HtmlWidget(controller.signature),
        )
      ],
    );
  }
}
