import 'package:flutter/material.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
import 'package:wahda_bank/features/authantication/screens/login/widgets/rounded_button.dart';
import 'package:wahda_bank/features/view/screens/drawer/compose/widgets/text_field.dart';

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
        TextFormField(
          controller: bodyCtrl,
          validator: (String? v) {
            if (v == null || v.isEmpty) {
              return "Please enter body";
            }
            return null;
          },
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: "Compose email",
            hintStyle: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          maxLines: null,
          onChanged: (value) {},
        ),
        SizedBox(
          height: MediaQuery.of(context).size.height / 2,
        ),
        WRoundedButton(controller: controller!, onPress: () {}, text: 'Send')
      ],
    );
  }
}
