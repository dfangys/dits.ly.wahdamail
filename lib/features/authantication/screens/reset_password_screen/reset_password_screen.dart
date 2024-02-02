import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/features/authantication/screens/reset_password_screen/reset_text_field.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';

// ignore: must_be_immutable
class ResetPasswordScreen extends StatelessWidget {
  ResetPasswordScreen({super.key});
  bool isBusy = false;
  final TextEditingController emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Column(
        children: [
          const SizedBox(height: 80),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SvgPicture.asset(
              WImages.logo,
              fit: BoxFit.cover,
              // ignore: deprecated_member_use
              color: Colors.white,
              width: Get.width * 0.7,
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: ResetPasswordTextField(),
          ),
        ],
      ),
    );
  }
}
