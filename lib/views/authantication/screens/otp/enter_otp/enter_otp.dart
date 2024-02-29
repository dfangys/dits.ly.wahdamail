import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:otp_text_field/otp_text_field.dart';
import 'package:otp_text_field/style.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
import 'package:wahda_bank/app/controllers/otp_controller.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';
import '../../login/widgets/rounded_button.dart';

class EnterOtpScreen extends GetView<OtpController> {
  EnterOtpScreen({super.key});

  final RoundedLoadingButtonController btnController =
      RoundedLoadingButtonController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
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
                child: Column(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),
                        const Text(
                          "Enter OTP",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 30,
                          ),
                        ),
                        const SizedBox(
                          width: 75,
                          child: Divider(
                            height: 10,
                            thickness: 3,
                            color: Color(0xFF0A993C),
                          ),
                        ),
                        const SizedBox(height: WSizes.defaultSpace),
                        const Text(
                          "An one time password sent to your email id and \n"
                          " phone number \n",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF37373F)),
                        ),
                        const SizedBox(height: 20),
                        OTPTextField(
                          length: 5,
                          controller: controller.fieldController,
                          width: MediaQuery.of(context).size.width,
                          fieldWidth: 60,
                          style: const TextStyle(fontSize: 17),
                          textFieldAlignment: MainAxisAlignment.spaceAround,
                          otpFieldStyle: OtpFieldStyle(
                            backgroundColor: Colors.white,
                            focusBorderColor: Colors.white,
                          ),
                          fieldStyle: FieldStyle.box,
                          onCompleted: (pin) {
                            if (kDebugMode) {
                              print("Completed: $pin");
                            }
                            controller.verifyPhoneOtp(otp: pin);
                          },
                        ),
                        const SizedBox(height: WSizes.defaultSpace),
                        TextButton(
                          onPressed: () {
                            controller.requestOtp();
                          },
                          child: Text(
                            'Resend OTP',
                            style: TextStyle(
                              fontSize: 16,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: WSizes.defaultSpace),
                        WRoundedButton(
                          controller: btnController,
                          onPress: () {
                            controller.verifyPhoneOtp(otp: controller.otpPin);
                            btnController.reset();
                          },
                          text: 'Submit',
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
