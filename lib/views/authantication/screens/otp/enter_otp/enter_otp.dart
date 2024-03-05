import 'dart:io';

import 'package:clipboard/clipboard.dart';
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
                        Text(
                          "enter_otp".tr,
                          style: const TextStyle(
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
                        Text(
                          "msg_otp_sent_to_your_email_and_phone".tr,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF37373F)),
                        ),
                        const SizedBox(height: 20),
                        _buildOtpField(context),
                        const SizedBox(height: WSizes.defaultSpace),
                        TextButton(
                          onPressed: () {
                            controller.requestOtp();
                          },
                          child: Text(
                            'resend_otp'.tr,
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
                            String code = "";
                            if (controller
                                .autoFillOtpController.text.isNotEmpty) {
                              code = controller.autoFillOtpController.text;
                            } else {
                              code = controller.otpPin;
                            }
                            controller.verifyPhoneOtp(otp: code);
                            btnController.reset();
                          },
                          text: 'continue'.tr,
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

  Widget _buildOtpField(BuildContext context) {
    // if (Platform.isIOS) {
    //   return SizedBox(
    //     width: MediaQuery.of(context).size.width * 0.7,
    //     child: TextFormField(
    //       keyboardType: TextInputType.number,
    //       maxLength: 5,
    //       textAlign: TextAlign.center,
    //       style: const TextStyle(fontSize: 17),
    //       decoration: InputDecoration(
    //         contentPadding: const EdgeInsets.all(10),
    //         hintText: 'Enter OTP',
    //         hintStyle: const TextStyle(fontSize: 17),
    //         border: OutlineInputBorder(
    //           borderRadius: BorderRadius.circular(10),
    //           borderSide: const BorderSide(color: Colors.white),
    //         ),
    //       ),
    //       onChanged: (value) {
    //         if (value.length == 5) {
    //           controller.verifyPhoneOtp(otp: value);
    //         }
    //       },
    //     ),
    //   );
    // }
    return OTPTextField(
      length: 5,
      controller: controller.fieldController,
      width: MediaQuery.of(context).size.width * 0.8,
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
      onChanged: (value) async {
        if (Platform.isIOS && value.length == 1) {
          String clipboardText = await FlutterClipboard.paste();
          controller.onSmsReceived(clipboardText);
        }
      },
    );
  }
}
