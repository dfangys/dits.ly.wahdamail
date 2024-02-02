import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/features/authantication/screens/login/widgets/text_form_field.dart';
import 'package:wahda_bank/features/authantication/screens/otp/verify_reset_password/verify_reset_password_otp.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';

// ignore: must_be_immutable
class ResetPasswordTextField extends StatelessWidget {
  ResetPasswordTextField({
    super.key,
  });
  bool isBusy = false;
  final TextEditingController emailController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Reset Password",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            if (isBusy) const CircularProgressIndicator.adaptive(),
            const SizedBox(height: 10),
            SizedBox(
              width: MediaQuery.of(context).size.width - 40,
              child: WTextFormField(
                controller: emailController,
                icon: WImages.mail,
                hintText: 'Email',
                obscureText: false,
                validatorText: 'Please enter email to continue',
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              width: MediaQuery.of(context).size.width - 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    shadowColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    )),
                onPressed: () {
                  Get.to(() => const VerifyResetPasswordOtpScreen());
                },
                child: const Text('Send Reset OTP'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
