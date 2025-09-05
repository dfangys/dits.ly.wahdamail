import 'dart:async';
import 'dart:io';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:pinput/pinput.dart';
import 'package:wahda_bank/infrastructure/api/mailsys_api_client.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';
import 'package:wahda_bank/utills/constants/text_strings.dart';
import 'package:wahda_bank/features/auth/presentation/screens/login/widgets/rounded_button.dart';
import 'package:wahda_bank/widgets/custom_loading_button.dart';

import 'package:wahda_bank/features/auth/presentation/screens/reset_password/reset_password_new_password_screen.dart';

class ResetPasswordOtpScreen extends StatefulWidget {
  const ResetPasswordOtpScreen({
    super.key,
    required this.email,
    this.maskedPhone,
  });
  final String email;
  final String? maskedPhone;

  @override
  State<ResetPasswordOtpScreen> createState() => _ResetPasswordOtpScreenState();
}

class _ResetPasswordOtpScreenState extends State<ResetPasswordOtpScreen> {
  final mailsys = Get.find<MailsysApiClient>();

  String otpPin = '';
  bool _isResending = false;
  bool _isSubmitting = false;
  int _resendSeconds = 0;
  Timer? _resendTimer;
  String? _maskedPhone;
  final CustomLoadingButtonController _btnController =
      CustomLoadingButtonController();

  @override
  void initState() {
    super.initState();
    _maskedPhone = widget.maskedPhone;
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = seconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds -= 1);
      }
    });
  }

  Future<void> _resendOtp() async {
    if (_isResending || _resendSeconds > 0) return;
    try {
      setState(() => _isResending = true);
      final res = await mailsys.requestPasswordReset(widget.email);
      // Try to read masked phone from various possible shapes
      final data =
          (res['data'] is Map) ? res['data'] as Map : <String, dynamic>{};
      final masked =
          data['masked_phone'] ??
          res['masked_phone'] ??
          data['phone_masked'] ??
          data['phone'];
      if (masked is String && masked.isNotEmpty) {
        setState(() => _maskedPhone = masked);
      }
      if (res['status'] == 'success' || data.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('OTP has been resent'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
        _startCountdown(60);
      }
    } on MailsysApiException catch (e) {
      if (mounted) {
        AwesomeDialog(
          context: context,
          dialogType: DialogType.error,
          title: 'error'.tr,
          desc: e.message,
          btnOkOnPress: () {},
        ).show();
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _continueToNewPassword() {
    if (_isSubmitting) return;
    if (otpPin.length != 5) {
      AwesomeDialog(
        context: context,
        dialogType: DialogType.warning,
        title: 'warning'.tr,
        desc: 'Please enter the complete 5-digit OTP code',
        btnOkOnPress: () {},
      ).show();
      return;
    }
    _btnController.start();
    setState(() => _isSubmitting = true);
    // Note: The API confirms OTP only together with new password.
    // We collect OTP here and verify on the next step with the password.
    Future.delayed(const Duration(milliseconds: 300), () {
      _btnController.success();
      Get.to(
        () => ResetPasswordNewPasswordScreen(email: widget.email, otp: otpPin),
      );
      Future.delayed(const Duration(milliseconds: 400), () {
        _btnController.reset();
        if (mounted) setState(() => _isSubmitting = false);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Column(
        children: [
          SizedBox(
            height:
                isTablet ? WSizes.imageThumbSize * 1.2 : WSizes.imageThumbSize,
          ),
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
                WImages.logoWhite,
                fit: BoxFit.cover,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
                width: Get.width * 0.7,
              ),
            ),
          ),
          SizedBox(
            height:
                isTablet
                    ? WSizes.spaceBtwSections * 1.2
                    : WSizes.spaceBtwSections,
          ),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, (1 - value) * 100),
                  child: Opacity(opacity: value, child: child),
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
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.1),
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
                          'Verify OTP'.tr,
                          style: TextStyle(
                            fontSize: isTablet ? 28 : 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 40 : 20,
                          vertical: 10,
                        ),
                        child: Text(
                          _maskedPhone != null && _maskedPhone!.isNotEmpty
                              ? 'An OTP has been sent to ${_maskedPhone!}'
                              : WText.verifyText,
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            fontWeight: FontWeight.w300,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      SizedBox(height: isTablet ? 20 : 10),
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            TextButton.icon(
                              onPressed:
                                  (_resendSeconds == 0 && !_isResending)
                                      ? _resendOtp
                                      : null,
                              icon: Icon(
                                Icons.refresh_rounded,
                                size: 18,
                                color: Theme.of(context).primaryColor,
                              ),
                              label: Text(
                                _resendSeconds > 0
                                    ? '${'resend_otp'.tr} (${_resendSeconds}s)'
                                    : 'resend_otp'.tr,
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
                      SizedBox(height: isTablet ? 20 : 10),
                      SizedBox(
                        height: 50,
                        width: MediaQuery.of(context).size.width - 50,
                        child: WRoundedButton(
                          controller: _btnController,
                          onPress: _continueToNewPassword,
                          text: 'Continue'.tr,
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
            color: Colors.black.withValues(alpha: 0.05),
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
          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration?.copyWith(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
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
          print('Completed: ' + pin);
        }
        otpPin = pin;
      },
      onChanged: (value) {
        otpPin = value;
        if (Platform.isIOS && value.length == 1) {
          // handle potential iOS paste behavior if needed
        }
      },
      crossAxisAlignment: CrossAxisAlignment.center,
      keyboardType: TextInputType.number,
      hapticFeedbackType: HapticFeedbackType.lightImpact,
      closeKeyboardWhenCompleted: false,
      useNativeKeyboard: true,
      animationDuration: const Duration(milliseconds: 300),
      animationCurve: Curves.easeInOut,
    );
  }
}
