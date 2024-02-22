import 'dart:io';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
import 'package:wahda_bank/app/apis/app_api.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/utills/constants/text_strings.dart';
import 'package:wahda_bank/views/authantication/screens/login/widgets/rounded_button.dart';
import 'package:wahda_bank/views/authantication/screens/login/widgets/text_form_field.dart';
import 'package:wahda_bank/views/authantication/screens/reset_password_screen/reset_password_screen.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';
import '../../../../app/controllers/otp_controller.dart';
import '../otp/otp_view/send_otp_view.dart';

// ignore: must_be_immutable
class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});
  TextEditingController emailCtrl = TextEditingController();
  TextEditingController passwordCtrl = TextEditingController();
  RoundedLoadingButtonController? controller = RoundedLoadingButtonController();
  final loginFormKey = GlobalKey<FormState>();
  final api = Get.put(AppApi());
  final otpController = Get.put(OtpController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
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
                      Text(
                        "login".tr,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 30,
                        ),
                      ),
                      SizedBox(
                        width: 75,
                        child: Divider(
                          height: 10,
                          thickness: 3,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(height: 40),
                      WTextFormField(
                        controller: emailCtrl,
                        icon: "assets/png/mail.png",
                        hintText: 'email'.tr,
                        obscureText: false,
                        domainFix: true,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'valid_required'.tr;
                          }
                          v = "$v${WText.emailSuffix}";
                          if (!v.isValidEmail()) {
                            return 'valid_email'.tr;
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
                              child: Text('reset_password'.tr),
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
                                mail: '${emailCtrl.text}${WText.emailSuffix}',
                                pass: passwordCtrl.text,
                              );
                              await MailService.instance.connect();
                              Get.to(() => const SendOtpView());
                            } on MailException catch (e) {
                              String message =
                                  e.message ?? 'Somthing went wrong';
                              if (message.startsWith('null')) {
                                message = "Authentication failed";
                              }
                              AwesomeDialog(
                                context: Get.context!,
                                dialogType: DialogType.error,
                                title: 'error'.tr,
                                desc: message,
                                btnOkOnPress: () {
                                  Get.back();
                                },
                              ).show();
                            } on SocketException catch (e) {
                              String message = e.toString();
                              if (e.toString().startsWith('null')) {
                                message = "Server not connected";
                              }
                              AwesomeDialog(
                                context: Get.context!,
                                dialogType: DialogType.error,
                                title: 'error'.tr,
                                desc: message,
                                btnOkOnPress: () {
                                  Get.back();
                                },
                              ).show();
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
