import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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

class _ResetPasswordTextFieldState extends State<ResetPasswordTextField> with SingleTickerProviderStateMixin {
  final bool isBusy = false;
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final appApi = Get.find<AppApi>();
  final btnController = RoundedLoadingButtonController();
  bool isError = false;
  bool _isEmailValid = true;
  final FocusNode _emailFocusNode = FocusNode();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _animationController.forward();
    _emailFocusNode.addListener(_onEmailFocusChange);
  }

  void _onEmailFocusChange() {
    if (!_emailFocusNode.hasFocus) {
      validateEmail();
    }
  }

  bool validateEmail() {
    final emailText = emailController.text.trim();
    if (emailText.isEmpty) {
      setState(() {
        _isEmailValid = false;
      });
      return false;
    }

    // Check for invalid characters
    final validCharsRegex = RegExp(r'^[a-zA-Z0-9.]+$');
    if (!validCharsRegex.hasMatch(emailText)) {
      setState(() {
        _isEmailValid = false;
      });
      return false;
    }

    setState(() {
      _isEmailValid = true;
    });
    return true;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailFocusNode.removeListener(_onEmailFocusChange);
    _emailFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                        "reset_password".tr,
                        style: TextStyle(
                          fontSize: isTablet ? 24 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
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

                    const SizedBox(height: 20),

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
                          "Enter your email to receive a password reset code",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),

                    if (isBusy)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator.adaptive(),
                      ),

                    const SizedBox(height: 20),

                    // Email field with animation
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 900),
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
                      child: _buildEmailField(context, isTablet),
                    ),

                    const SizedBox(height: 10),

                    if (isError)
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOut,
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
                              Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Something went wrong. Please try again.',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 30),

                    // Submit button with animation
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
                        onPress: submitForm,
                        text: "Send Reset OTP",
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Back button with animation
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
            padding: const EdgeInsets.all(16.0),
            child: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField(BuildContext context, bool isTablet) {
    return Container(
      width: MediaQuery.of(context).size.width - 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WTextFormField(
            controller: emailController,
            icon: WImages.mail,
            hintText: 'email'.tr,
            obscureText: false,
            domainFix: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'valid_email'.tr;
              }

              // Check for invalid characters
              final validCharsRegex = RegExp(r'^[a-zA-Z0-9.]+$');
              if (!validCharsRegex.hasMatch(value)) {
                return 'Only letters, numbers, and dots are allowed'.tr;
              }

              return null;
            },
          ),
          if (!_isEmailValid)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 6),
              child: Text(
                'Only letters, numbers, and dots are allowed',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future submitForm() async {
    setState(() {
      isError = false;
    });

    if (formKey.currentState!.validate()) {
      try {
        btnController.start();
        String email = emailController.text.trim() + WText.emailSuffix;
        var res = await appApi.sendResetPasswordOtp(email);
        if (res is Map && res.isNotEmpty) {
          if (res.containsKey('otp_send') && res['otp_send']) {
            btnController.success();
            Get.to(
                  () => VerifyResetPasswordOtpScreen(email: email),
            );
          } else {
            btnController.error();
            setState(() {
              isError = true;
            });
          }
        } else {
          btnController.error();
          setState(() {
            isError = true;
          });
        }
      } on AppApiException catch (e) {
        btnController.error();
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
        if (btnController.currentState != ButtonState.success) {
          Future.delayed(const Duration(seconds: 1), () {
            btnController.reset();
          });
        }
      }
    } else {
      btnController.reset();
    }
  }
}
