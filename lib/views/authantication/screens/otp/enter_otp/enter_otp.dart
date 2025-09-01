import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import 'package:wahda_bank/widgets/custom_loading_button.dart';
import 'package:wahda_bank/app/controllers/otp_controller.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';
import '../../login/widgets/rounded_button.dart';

class EnterOtpScreen extends GetView<OtpController> {
  EnterOtpScreen({super.key});

  final CustomLoadingButtonController btnController =
      CustomLoadingButtonController();

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Column(
        children: [
          SizedBox(
            height: isTablet ? WSizes.imageThumbSize * 1.2 : WSizes.imageThumbSize,
          ),
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
            child: SizedBox(
              height: isTablet ? 110 : 85,
              width: isTablet ? 280 : 221,
              child: SvgPicture.asset(
                WImages.splash,
                fit: BoxFit.contain,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          const SizedBox(
            height: WSizes.defaultSpace,
          ),
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
                constraints: const BoxConstraints.expand(),
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: AppTheme.cardDesignColor,
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: isTablet ? 80 : 60),
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
                              "enter_otp".tr,
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: isTablet ? 36 : 30,
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
                            child: SizedBox(
                              width: 75,
                              child: Divider(
                                height: 10,
                                thickness: 3,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: WSizes.defaultSpace),
                          // Message with animation
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
                              padding: EdgeInsets.symmetric(horizontal: isTablet ? 40 : 20),
                              child: Text(
                                "msg_otp_sent_to_your_email_and_phone".tr,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: const Color(0xFF37373F),
                                  fontSize: isTablet ? 16 : 14,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: isTablet ? 30 : 20),
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
                          SizedBox(height: isTablet ? WSizes.defaultSpace * 1.5 : WSizes.defaultSpace),
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
                            child: Obx(() {
                              final secs = controller.resendSeconds.value;
                              final busy = controller.isRequestingOtp.value;
                              final canResend = secs == 0 && !busy;
                              final label = secs == 0
                                  ? 'resend_otp'.tr
                                  : 'resend_otp'.tr + ' (${secs}s)';
                              return TextButton.icon(
                                onPressed: canResend
                                    ? () async {
                                        await controller.resendOtp();
                                      }
                                    : null,
                                icon: Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                  color: Theme.of(context).primaryColor,
                                ),
                                label: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: isTablet ? 18 : 16,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              );
                            }),
                          ),
                          SizedBox(height: isTablet ? WSizes.defaultSpace * 1.5 : WSizes.defaultSpace),
                          // Continue button with animation
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
                            child: WRoundedButton(
                              controller: btnController,
                              onPress: () {
                                String code = "";
                                if (controller.autoFillOtpController.text.isNotEmpty) {
                                  code = controller.autoFillOtpController.text;
                                } else {
                                  code = controller.otpPin;
                                }
                                controller.verifyPhoneOtp(otp: code);
                                btnController.reset();
                              },
                              text: 'continue'.tr,
                            ),
                          ),
                          SizedBox(height: isTablet ? 40 : 20),
                        ],
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

  Widget _buildPinput(BuildContext context, bool isTablet) {
    final defaultPinTheme = PinTheme(
      width: isTablet ? 70 : 56,
      height: isTablet ? 70 : 56,
      textStyle: TextStyle(
        fontSize: isTablet ? 22 : 18,
        color: AppTheme.textPrimaryColor,
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

      // fires when the user finishes typing
      onCompleted: (pin) {
        controller.otpPin = pin;
        controller.verifyPhoneOtp(otp: pin);
      },

      // fires on every keystroke
      onChanged: (value) => controller.otpPin = value,

      // ✔ iOS/Android clipboard support straight from Pinput
      onClipboardFound: (code) {
        controller.otpPin = code;
        controller.verifyPhoneOtp(otp: code);
      },

      // ✔ Android SMS autofill (optional – see next section)
      // smsRetriever: controller.smsRetriever,   // your own implementation

      crossAxisAlignment: CrossAxisAlignment.center,
      keyboardType: TextInputType.number,
      hapticFeedbackType: HapticFeedbackType.lightImpact,
      closeKeyboardWhenCompleted: false,
      useNativeKeyboard: true,
      animationDuration: const Duration(milliseconds: 300),
      animationCurve: Curves.easeInOut,
    );  }
}
