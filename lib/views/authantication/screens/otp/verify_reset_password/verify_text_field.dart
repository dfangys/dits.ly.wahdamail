import 'package:flutter/material.dart';
import 'package:otp_text_field/otp_field.dart';
import 'package:otp_text_field/otp_field_style.dart';
import 'package:otp_text_field/style.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
import 'package:wahda_bank/views/authantication/screens/login/widgets/rounded_button.dart';
import 'package:wahda_bank/views/authantication/screens/login/widgets/text_form_field.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';
import 'package:wahda_bank/utills/constants/text_strings.dart';

// ignore: must_be_immutable
class VerifyTextField extends StatelessWidget {
  VerifyTextField({
    super.key,
  });

  final otpController = OtpFieldController();
  final TextEditingController passwordController = TextEditingController();
  RoundedLoadingButtonController controller = RoundedLoadingButtonController();
  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Column(
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
          onCompleted: (pin) {},
        ),
        const SizedBox(height: WSizes.defaultSpace),
        SizedBox(
          width: MediaQuery.of(context).size.width - 40,
          child: Form(
            key: formKey,
            child: WTextFormField(
              controller: passwordController,
              icon: WImages.lock,
              hintText: 'Password',
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
            onPress: () {},
            text: 'Reset Password',
          ),
        ),
      ],
    );
  }
}
