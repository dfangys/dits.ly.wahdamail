import 'dart:io';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:otp_text_field/otp_text_field.dart';
import 'package:otp_text_field/style.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
import 'package:telephony/telephony.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';

import '../../../../../app/apis/app_api.dart';
import '../../../../../utills/constants/text_strings.dart';
import '../../login/login.dart';
import '../../login/widgets/rounded_button.dart';
import '../../login/widgets/text_form_field.dart';

class VerifyResetPasswordOtpScreen extends StatefulWidget {
  const VerifyResetPasswordOtpScreen({super.key, required this.email});
  final String email;
  @override
  State<VerifyResetPasswordOtpScreen> createState() =>
      _VerifyResetPasswordOtpScreenState();
}

class _VerifyResetPasswordOtpScreenState
    extends State<VerifyResetPasswordOtpScreen> {
  Telephony telephony = Telephony.instance;
  final otpController = OtpFieldController();
  final TextEditingController passwordController = TextEditingController();
  RoundedLoadingButtonController controller = RoundedLoadingButtonController();
  final formKey = GlobalKey<FormState>();
  String otpPin = '';

  @override
  void initState() {
    listenForSms();
    super.initState();
  }

  Future listenForSms() async {
    if (Platform.isAndroid) {
      bool? permissionsGranted = await telephony.requestSmsPermissions;
      if (permissionsGranted != null && permissionsGranted) {
        telephony.listenIncomingSms(
          onNewMessage: (SmsMessage message) {
            onSmsReceived(message.body);
          },
          listenInBackground: false,
        );
      }
    }
  }

  void onSmsReceived(String? message) {
    if (message != null) {
      var match = RegExp(r'\d+').firstMatch(message);
      if (match != null) {
        String numCode = match.group(0) ?? '';
        otpController.set(numCode.split(''));
        otpPin = numCode;
      }
    }
  }

  final appApi = Get.find<AppApi>();
  Future verifyOtp() async {
    if (formKey.currentState!.validate()) {
      try {
        var data = await appApi.resetPassword(
          widget.email,
          passwordController.text,
          otpPin,
        );
        if (data is Map) {
          if (data.containsKey('verified') && data['verified']) {
            AwesomeDialog(
              context: context,
              dialogType: DialogType.success,
              title: 'Success',
              desc: 'Password reset successfully',
              btnOkOnPress: () {
                Get.offAll(() => LoginScreen());
              },
            ).show();
          } else {
            AwesomeDialog(
              context: context,
              dialogType: DialogType.error,
              title: 'error'.tr,
              desc: data['message'] ?? 'Something went wrong',
            ).show();
          }
        } else {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.error,
            title: 'Error',
            desc: data['message'] ?? 'Something went wrong',
          ).show();
        }
      } on AppApiException catch (e) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'error'.tr,
          desc: e.message,
        ).show();
      } catch (e) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'error'.tr,
          desc: e.toString(),
        ).show();
      }
    }
  }

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
                child: Column(
                  children: [
                    const SizedBox(height: 50),
                    const Text(
                      "Enter OTP & Password",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 6,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const Text(
                      WText.verifyText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    OTPTextField(
                      length: 5,
                      width: MediaQuery.of(context).size.width - 30,
                      fieldWidth: 50,
                      style: const TextStyle(fontSize: 17),
                      textFieldAlignment: MainAxisAlignment.spaceAround,
                      fieldStyle: FieldStyle.box,
                      controller: otpController,
                      otpFieldStyle: OtpFieldStyle(
                        backgroundColor: Colors.white,
                      ),
                      onCompleted: (pin) {
                        otpPin = pin;
                        verifyOtp();
                      },
                    ),
                    const SizedBox(height: WSizes.defaultSpace),
                    SizedBox(
                      width: MediaQuery.of(context).size.width - 40,
                      child: Form(
                        key: formKey,
                        child: WTextFormField(
                          controller: passwordController,
                          icon: WImages.lock,
                          hintText: 'password'.tr,
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            } else if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                    const Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 5,
                          ),
                          child: Text(
                            WText.verifyText2,
                            textAlign: TextAlign.start,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 50,
                      width: MediaQuery.of(context).size.width - 50,
                      child: WRoundedButton(
                        controller: controller,
                        onPress: () {
                          verifyOtp();
                        },
                        text: 'reset_password'.tr,
                      ),
                    ),
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
