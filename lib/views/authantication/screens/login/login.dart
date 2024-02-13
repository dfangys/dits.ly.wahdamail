import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/views/authantication/screens/login/widgets/rounded_button.dart';
import 'package:wahda_bank/views/authantication/screens/login/widgets/text_form_field.dart';
import 'package:wahda_bank/views/authantication/screens/reset_password_screen/reset_password_screen.dart';
import 'package:wahda_bank/utills/constants/colors.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';

import '../../../view/screens/first_loading_view.dart';

// ignore: must_be_immutable
class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});
  TextEditingController emailCtrl = TextEditingController();
  TextEditingController passwordCtrl = TextEditingController();
  RoundedLoadingButtonController? controller = RoundedLoadingButtonController();
  final loginFormKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WColors.welcomeScafhold,
      body: Column(
        children: [
          const SizedBox(height: 80),
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
          const SizedBox(
            height: WSizes.spaceBtwSections,
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints.expand(),
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: loginFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: WSizes.spaceBtwSections),
                      const Text(
                        "Login",
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
                          color: WColors.welcomeScafhold,
                        ),
                      ),
                      const SizedBox(height: 40),
                      WTextFormField(
                        controller: emailCtrl,
                        icon: "assets/png/mail.png",
                        hintText: 'Email',
                        obscureText: false,
                        domainFix: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please enter email to continue';
                          }
                          v = "$v@schooloftechnologies.com";
                          if (!GetUtils.isEmail(v)) {
                            return 'Please enter valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(
                        height: WSizes.defaultSpace,
                      ),
                      WTextFormField(
                        controller: passwordCtrl,
                        icon: 'assets/png/lock.png',
                        hintText: 'Password',
                        obscureText: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please enter password to continue';
                          } else if (v.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                Get.to(() => ResetPasswordScreen());
                              },
                              child: const Text('Reset Password'),
                            ),
                          ],
                        ),
                      ),
                      WRoundedButton(
                        controller: controller!,
                        onPress: () async {
                          if (loginFormKey.currentState!.validate()) {
                            try {
                              controller!.start();
                              await MailService.instance.init(
                                mail:
                                    '${emailCtrl.text}@schooloftechnologies.com',
                                pass: passwordCtrl.text,
                              );
                              await MailService.instance.connect();
                              Get.to(() => const LoadingFirstView());
                            } on MailException catch (e) {
                              String message =
                                  e.message ?? 'Somthing went wrong';
                              if (message.startsWith('null')) {
                                message = "Authentication failed";
                              }
                              Get.showSnackbar(GetSnackBar(
                                message: message,
                                duration: const Duration(seconds: 3),
                              ));
                            } catch (e) {
                              String message = e.toString();
                              if (e.toString().startsWith('null')) {
                                message = "Server not connected";
                              }
                              Get.showSnackbar(GetSnackBar(
                                message: message,
                                duration: const Duration(seconds: 3),
                              ));
                            } finally {
                              controller!.stop();
                            }
                          } else {
                            controller!.stop();
                          }
                        },
                        text: 'Login',
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
