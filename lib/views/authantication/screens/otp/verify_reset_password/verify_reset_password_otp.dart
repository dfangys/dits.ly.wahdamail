import 'dart:io';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
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
  final TextEditingController passwordController = TextEditingController();
  RoundedLoadingButtonController controller = RoundedLoadingButtonController();
  final formKey = GlobalKey<FormState>();
  String otpPin = '';

  @override
  void initState() {
    super.initState();
  }

  final appApi = Get.find<AppApi>();

  Future verifyOtp() async {
    if (formKey.currentState!.validate() && otpPin.length == 5) {
      try {
        controller.start();
        var data = await appApi.resetPassword(
          widget.email,
          passwordController.text,
          otpPin,
        );
        if (data is Map && mounted) {
          if (data.containsKey('verified') && data['verified']) {
            controller.success();
            AwesomeDialog(
              context: context,
              dialogType: DialogType.success,
              title: 'success'.tr,
              desc: 'msg_password_reset_successfully'.tr,
              btnOkOnPress: () {
                Get.offAll(() => LoginScreen());
              },
            ).show();
            Get.offAll(() => LoginScreen());
          } else {
            controller.error();
            AwesomeDialog(
              context: context,
              dialogType: DialogType.error,
              title: 'error'.tr,
              desc: data['message'] ?? 'msg_some_thing_went_wrong'.tr,
              btnOkOnPress: () {
                controller.reset();
              },
            ).show();
          }
        } else if (mounted) {
          controller.error();
          AwesomeDialog(
            context: context,
            dialogType: DialogType.error,
            title: 'Error',
            desc: data['message'] ?? 'msg_some_thing_went_wrong'.tr,
            btnOkOnPress: () {
              controller.reset();
            },
          ).show();
        }
      } on AppApiException catch (e) {
        controller.error();
        if (mounted) {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.error,
            title: 'error'.tr,
            desc: e.message,
            btnOkOnPress: () {
              controller.reset();
            },
          ).show();
        }
      } catch (e) {
        controller.error();
        if (mounted) {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.error,
            title: 'error'.tr,
            desc: e.toString(),
            btnOkOnPress: () {
              controller.reset();
            },
          ).show();
        }
      }
    } else {
      if (otpPin.length < 5) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.warning,
          title: 'warning'.tr,
          desc: 'Please enter the complete 5-digit OTP code',
          btnOkOnPress: () {},
        ).show();
      }
    }
  }

  Future resendSms() async {
    try {
      String email = widget.email;
      var res = await appApi.sendResetPasswordOtp(email);
      if (res is Map && res.isNotEmpty) {
        if (res.containsKey('otp_send') && res['otp_send']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('OTP code has been resent to your email'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } on AppApiException catch (e) {
      if (mounted) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'error'.tr,
          desc: e.message,
          btnOkOnPress: () {},
        ).show();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Column(
        children: [
          SizedBox(height: isTablet ? WSizes.imageThumbSize * 1.2 : WSizes.imageThumbSize),
          // Logo with animation
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * 30),
                  child: child,
                ),
              );
            },
            child: Padding(
              padding: EdgeInsets.all(isTablet ? 24 : 20),
              child: SvgPicture.asset(
                WImages.logo,
                fit: BoxFit.cover,
                // ignore: deprecated_member_use
                color: Colors.white,
                width: Get.width * 0.7,
              ),
            ),
          ),
          SizedBox(height: isTablet ? WSizes.spaceBtwSections * 1.2 : WSizes.spaceBtwSections),
          // Main content container with animation
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, (1 - value) * 100),
                  child: Opacity(
                    opacity: value,
                    child: child,
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha : 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Back button
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha : 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: isTablet ? 10 : 5),
                      
                      // Title with animation
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, (1 - value) * 20),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          "msg_enter_and_password".tr,
                          style: TextStyle(
                            fontSize: isTablet ? 28 : 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      
                      // Divider with animation
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scaleX: value,
                            alignment: Alignment.center,
                            child: child,
                          );
                        },
                        child: Container(
                          width: 60,
                          height: 6,
                          margin: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      
                      // Instruction text with animation
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: child,
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 40 : 20,
                            vertical: 10,
                          ),
                          child: Text(
                            WText.verifyText,
                            style: TextStyle(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.w300,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      
                      SizedBox(height: isTablet ? 20 : 10),
                      
                      // OTP field with animation
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, (1 - value) * 30),
                              child: child,
                            ),
                          );
                        },
                        child: _buildPinput(context, isTablet),
                      ),
                      
                      SizedBox(height: isTablet ? 20 : 10),
                      
                      // Resend button with animation
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: child,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              TextButton.icon(
                                onPressed: resendSms,
                                icon: Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                  color: Theme.of(context).primaryColor,
                                ),
                                label: Text(
                                  'resend_otp'.tr,
                                  style: TextStyle(
                                    fontSize: isTablet ? 16 : 14,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Password field with animation
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, (1 - value) * 30),
                              child: child,
                            ),
                          );
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 30 : 20,
                            vertical: 10,
                          ),
                          child: Form(
                            key: formKey,
                            child: WTextFormField(
                              controller: passwordController,
                              // icon: WImages.lock,
                              hintText: 'password'.tr,
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'valid_password'.tr;
                                } else if (value.length < 8) {
                                  return 'password_must_be_at_least_8_characters'
                                      .tr;
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                      ),
                      
                      // Password requirements text with animation
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: child,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 5,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  WText.verifyText2,
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                    fontSize: isTablet ? 14 : 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      SizedBox(height: isTablet ? 20 : 10),
                      
                      // Reset button with animation
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, (1 - value) * 30),
                              child: child,
                            ),
                          );
                        },
                        child: SizedBox(
                          height: 50,
                          width: MediaQuery.of(context).size.width - 50,
                          child: WRoundedButton(
                            controller: controller,
                            onPress: verifyOtp,
                            text: 'reset_password'.tr,
                          ),
                        ),
                      ),
                      
                      SizedBox(height: isTablet ? 40 : 20),
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

  Widget _buildPinput(BuildContext context, bool isTablet) {
    final defaultPinTheme = PinTheme(
      width: isTablet ? 70 : 56,
      height: isTablet ? 70 : 56,
      textStyle: TextStyle(
        fontSize: isTablet ? 22 : 18,
        color: Theme.of(context).textTheme.bodyLarge?.color,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha : 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: Theme.of(context).primaryColor, width: 2),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Theme.of(context).primaryColor.withValues(alpha : 0.2),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        color: Theme.of(context).primaryColor.withValues(alpha : 0.1),
        border: Border.all(color: Theme.of(context).primaryColor),
      ),
    );

    return Pinput(
      length: 5,
      defaultPinTheme: defaultPinTheme,
      focusedPinTheme: focusedPinTheme,
      submittedPinTheme: submittedPinTheme,
      pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
      showCursor: true,
      cursor: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 9),
            width: 22,
            height: 2,
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
      onCompleted: (pin) {
        if (kDebugMode) {
          print("Completed: $pin");
        }
        otpPin = pin;
      },
      onChanged: (value) {
        otpPin = value;
        if (Platform.isIOS && value.length == 1) {
          // Handle iOS clipboard paste if needed
        }
      },
      crossAxisAlignment: CrossAxisAlignment.center,
      keyboardType: TextInputType.number,
      // androidSmsAutofillMethod: AndroidSmsAutofillMethod.smsUserConsentApi,
      hapticFeedbackType: HapticFeedbackType.lightImpact,
      closeKeyboardWhenCompleted: false,
      useNativeKeyboard: true,
      animationDuration: const Duration(milliseconds: 300),
      animationCurve: Curves.easeInOut,
    );
  }
}
