import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
import 'package:wahda_bank/views/authantication/screens/login/widgets/rounded_button.dart';
import 'package:wahda_bank/views/view/screens/drawer/compose/widgets/text_field.dart';

// ignore: must_be_immutable
class WComposeView extends StatelessWidget {
  WComposeView({
    super.key,
  });

  final fromCtrl = TextEditingController();
  final toCtrl = TextEditingController();
  final bodyCtrl = TextEditingController();
  final subCtrl = TextEditingController();
  final ccCtrl = TextEditingController();
  final bccCtrl = TextEditingController();
  RoundedLoadingButtonController? controller = RoundedLoadingButtonController();
  final HtmlEditorController htmlController = HtmlEditorController();
  List<String> bcclist = [];
  List<String> emails = [];
  List<String> cclist = [];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(
          height: 40,
        ),
        Visibility(
          child: Column(
            children: [
              ToEmailsChipsField(
                title: "To",
                emails: cclist,
                controller: ccCtrl,
                onDelete: (String cc) {},
                onInsert: (String cc) {},
              ),
              const Divider(color: Colors.grey, thickness: 0.5),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Visibility(
          child: Column(
            children: [
              ToEmailsChipsField(
                title: "From",
                emails: cclist,
                controller: fromCtrl,
                onDelete: (String cc) {},
                onInsert: (String cc) {},
              ),
              const Divider(color: Colors.grey, thickness: 0.5),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Visibility(
          child: Column(
            children: [
              ToEmailsChipsField(
                title: "Subject",
                emails: cclist,
                controller: subCtrl,
                onDelete: (String cc) {},
                onInsert: (String cc) {},
              ),
              const Divider(color: Colors.grey, thickness: 0.5),
            ],
          ),
        ),
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
          controller: controller!,
          onPress: () {},
          text: 'Send',
        )
      ],
    );
  }
}
