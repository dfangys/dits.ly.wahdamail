import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:otp_text_field/otp_field.dart';
import 'package:otp_text_field/style.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
import 'package:wahda_bank/features/authantication/screens/login/widgets/rounded_button.dart';
import 'package:wahda_bank/features/view/screens/home/home.dart';
import 'package:wahda_bank/utills/constants/colors.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';

// ignore: must_be_immutable
class EnterOtpScreen extends StatelessWidget {
  EnterOtpScreen({Key? key}) : super(key: key);
  RoundedLoadingButtonController? controller = RoundedLoadingButtonController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WColors.welcomeScafhold,
      body: Column(
        children: [
          const SizedBox(
            height: 80,
          ),
          SizedBox(
              height: 100,
              width: 200,
              child: Image.asset(
                WImages.splash,
                fit: BoxFit.fill,
              )),
          const SizedBox(
            height: 20,
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints.expand(),
              margin: const EdgeInsets.only(top: 5),
              decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25))),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    const Text(
                      "Enter OTP",
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 30),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "An one time password sent to your email id and \n"
                      " phone number \n",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(
                        width: 75,
                        child: Divider(
                            height: 10,
                            thickness: 3,
                            color: Color(0xFF0A993C))),
                    const SizedBox(height: 40),
                    OTPTextField(
                      length: 4,
                      width: MediaQuery.of(context).size.width,
                      fieldWidth: 60,
                      style: const TextStyle(fontSize: 17),
                      textFieldAlignment: MainAxisAlignment.spaceAround,
                      fieldStyle: FieldStyle.box,
                      onCompleted: (pin) {
                        if (kDebugMode) {
                          print("Completed: $pin");
                        }
                      },
                    ),
                    const SizedBox(
                      height: 30,
                    ),
                    WRoundedButton(
                        controller: controller!,
                        onPress: () {
                          Get.to(const HomeScreen());
                        },
                        text: 'Submit')
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
