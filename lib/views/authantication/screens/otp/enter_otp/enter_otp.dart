import 'package:flutter/material.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/views/authantication/screens/otp/enter_otp/enter_otp_field.dart';
import 'package:wahda_bank/utills/constants/colors.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';

// ignore: must_be_immutable
class EnterOtpScreen extends StatelessWidget {
  const EnterOtpScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WColors.welcomeScafhold,
      body: Column(
        children: [
          const SizedBox(
            height: WSizes.imageThumbSize,
          ),
          SizedBox(
            height: 85,
            width: 221,
            child: Image.asset(
              WImages.splash,
              fit: BoxFit.fill,
            ),
          ),
          const SizedBox(
            height: WSizes.defaultSpace,
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints.expand(),
              margin: const EdgeInsets.only(top: 5),
              decoration: const BoxDecoration(
                color: AppTheme.cardDesignColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: SingleChildScrollView(
                child: EnterOtpfield(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
