import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
import 'package:wahda_bank/app/apis/app_api.dart';
import 'package:wahda_bank/utills/constants/text_strings.dart';
import 'package:wahda_bank/views/authantication/screens/login/widgets/rounded_button.dart';
import 'package:wahda_bank/views/authantication/screens/login/widgets/text_form_field.dart';
import 'package:wahda_bank/views/authantication/screens/otp/verify_reset_password/verify_reset_password_otp.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';

class ResetPasswordTextField extends StatefulWidget {
  const ResetPasswordTextField({
    super.key,
  });

  @override
  State<ResetPasswordTextField> createState() => _ResetPasswordTextFieldState();
}

class _ResetPasswordTextFieldState extends State<ResetPasswordTextField> {
  final bool isBusy = false;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();

  final appApi = Get.find<AppApi>();

  final btnController = RoundedLoadingButtonController();
  bool isError = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
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
                      icon: Icon(Iconsax.sms),
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
                  const SizedBox(height: 10),
                  if (isError)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(child: Text('Something went wrong')),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  WRoundedButton(
                    controller: btnController,
                    onPress: submitForm,
                    text: "Send Reset OTP",
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back),
          ),
        ),
      ],
    );
  }

  Future submitForm() async {
    if (formKey.currentState!.validate()) {
      try {
        String email = emailController.text.trim() + WText.emailSuffix;
        var res = await appApi.sendResetPasswordOtp(email);
        if (res is Map && res.isNotEmpty) {
          if (res.containsKey('otp_send') && res['otp_send']) {
            Get.to(
              () => VerifyResetPasswordOtpScreen(email: email),
            );
          }
        }
      } on AppApiException catch (e) {
        setState(() {
          isError = true;
        });
        if (mounted) {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.error,
            title: 'error'.tr,
            desc: e.message,
            btnOkOnPress: () {},
            btnOkColor: Theme.of(context).primaryColor,
          ).show();
        }
      } finally {
        btnController.stop();
      }
    }
  }
}
