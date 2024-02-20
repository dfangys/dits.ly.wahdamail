import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/apis/app_api.dart';
import 'package:wahda_bank/app/controllers/otp_controller.dart';
import 'package:wahda_bank/utills/constants/text_strings.dart';
import 'package:wahda_bank/views/authantication/screens/login/widgets/text_form_field.dart';
import 'package:wahda_bank/views/authantication/screens/otp/verify_reset_password/verify_reset_password_otp.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';

class ResetPasswordTextField extends StatelessWidget {
  ResetPasswordTextField({
    super.key,
  });
  final bool isBusy = false;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final appApi = Get.find<AppApi>();

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
        child: Form(
          key: formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "reset_password".tr,
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
                  hintText: 'email'.tr,
                  obscureText: false,
                  domainFix: true,
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'valid_email'.tr;
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
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      try {
                        String email =
                            emailController.text.trim() + WText.emailSuffix;
                        var res = await appApi.sendResetPasswordOtp(email);
                        if (res is Map && res.isNotEmpty) {
                          if (res.containsKey('otp_send') && res['otp_send']) {
                            Get.to(() => VerifyResetPasswordOtpScreen(
                                  email: email,
                                ));
                          } else {
                            AwesomeDialog(
                              context: context,
                              dialogType: DialogType.error,
                              title: 'error'.tr,
                              desc: res['message'] ?? 'error'.tr,
                              btnCancelOnPress: () {},
                            ).show();
                          }
                        }
                      } catch (e) {
                        AwesomeDialog(
                          context: context,
                          dialogType: DialogType.error,
                          title: 'error'.tr,
                          desc: e.toString(),
                          btnCancelOnPress: () {},
                        ).show();
                      }
                    }
                  },
                  child: const Text('Send Reset OTP'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
