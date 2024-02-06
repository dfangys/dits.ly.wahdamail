import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/authantication/screens/otp/verify_reset_password/verify_text_field.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';

// ignore: must_be_immutable
class VerifyResetPasswordOtpScreen extends StatelessWidget {
  const VerifyResetPasswordOtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Column(
        children: [
          const SizedBox(height: WSizes.imageThumbSize),
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
          const SizedBox(height: WSizes.spaceBtwSections),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: SingleChildScrollView(
                child: VerifyTextField(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
