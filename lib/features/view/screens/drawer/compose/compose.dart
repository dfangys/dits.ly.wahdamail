import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/features/view/screens/drawer/compose/widgets/compose_action_button.dart';
import 'package:wahda_bank/features/view/screens/drawer/compose/widgets/compose_view.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';

class ComposeScreen extends StatelessWidget {
  ComposeScreen({super.key});
  final composeFormKey = GlobalKey<FormState>();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
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
        actions: const [
          ComposeActionButton(),
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
