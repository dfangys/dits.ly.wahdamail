import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/authantication/screens/login/widgets/text_form_field.dart';
import 'package:wahda_bank/views/authantication/screens/otp/verify_reset_password/verify_reset_password_otp.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';

class ResetPasswordTextField extends StatelessWidget {
  ResetPasswordTextField({
    super.key,
  });
  final bool isBusy = false;
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
                domainFix: true,
                validator: (value) {
                  if (value!.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!GetUtils.isEmail(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
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
                  ),
                ),
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
