import 'dart:io';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
import 'package:wahda_bank/app/apis/app_api.dart';
// import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/views/authantication/screens/reset_password_screen/reset_password_screen.dart';
import 'package:wahda_bank/app/controllers/selection_controller.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/utills/constants/text_strings.dart';
import 'package:wahda_bank/views/authantication/screens/login/widgets/rounded_button.dart';
import 'package:wahda_bank/views/authantication/screens/login/widgets/text_form_field.dart';
import 'package:wahda_bank/views/authantication/screens/reset_password_screen/reset_password_screen.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';
import 'package:wahda_bank/views/view/screens/home/home.dart';
import '../../../../app/controllers/otp_controller.dart';
import '../otp/otp_view/send_otp_view.dart';

// ignore: must_be_immutable
class LoginScreen extends StatefulWidget {
  LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  TextEditingController emailCtrl =
  TextEditingController(text: kDebugMode ? "abdullah.salemnaseeb" : "");
  TextEditingController passwordCtrl =
  TextEditingController(text: kDebugMode ? "Aa102030.@" : "");
  RoundedLoadingButtonController? controller = RoundedLoadingButtonController();
  final loginFormKey = GlobalKey<FormState>();
  final api = Get.put(AppApi());
  final otpController = Get.put(OtpController());

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  bool _obscurePassword = true;
  bool _isEmailValid = true;
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

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

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();

    _emailFocusNode.addListener(_onEmailFocusChange);
  }

  void _onEmailFocusChange() {
    if (!_emailFocusNode.hasFocus) {
      validateEmail();
    }
  }

  bool validateEmail() {
    final emailText = emailCtrl.text.trim();
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
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Column(
        children: [
          SizedBox(height: isTablet ? 100 : 80),
          // Logo with animation
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: EdgeInsets.all(isTablet ? 30 : 20),
                child: SvgPicture.asset(
                  WImages.logo,
                  fit: BoxFit.cover,
                  // ignore: deprecated_member_use
                  color: Colors.white,
                  width: Get.width * (isTablet ? 0.6 : 0.7),
                ),
              ),
            ),
          ),
          SizedBox(
            height: isTablet ? WSizes.spaceBtwSections * 1.2 : WSizes.spaceBtwSections,
          ),
          // Main content container with animation
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Container(
                  constraints: const BoxConstraints.expand(),
                  margin: const EdgeInsets.only(top: 5),
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
                  child: SingleChildScrollView(
                    child: Form(
                      key: loginFormKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: isTablet ? WSizes.spaceBtwSections * 1.2 : WSizes.spaceBtwSections),
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
                              "login".tr,
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
                          SizedBox(height: isTablet ? 60 : 40),

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

                          SizedBox(
                            height: isTablet ? WSizes.defaultSpace * 1.5 : WSizes.defaultSpace,
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
                            child: _buildPasswordField(context, isTablet),
                          ),

                          // Reset password link with animation
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 1100),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: child,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  TextButton.icon(
                                    onPressed: () {
                                      Get.to(() => ResetPasswordScreen());
                                    },
                                    icon: Icon(
                                      Icons.lock_reset_rounded,
                                      size: 18,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                    label: Text(
                                      'reset_password'.tr,
                                      style: TextStyle(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.w500,
                                        fontSize: isTablet ? 16 : 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: isTablet ? 20 : 10),

                          // Login button with animation
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: 1.0),
                            duration: const Duration(milliseconds: 1200),
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
                              controller: controller!,
                              onPress: () async {
                                if (loginFormKey.currentState!.validate()) {
                                  try {
                                    controller!.start();
                                    await MailService.instance.init(
                                      mail: '${emailCtrl.text.trim()}${WText.emailSuffix}',
                                      pass: passwordCtrl.text,
                                    );
                                    await MailService.instance.connect();
                                    Get.to(() => const SendOtpView());
                                  } on MailException catch (e) {
                                    String message =
                                        e.message ?? 'msg_some_thing_went_wrong'.tr;
                                    if (message.startsWith('null')) {
                                      message = "msg_auth_failed".tr;
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
                                      message = "msg_server_error".tr;
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
                              text: 'login'.tr,
                            ),
                          ),

                          SizedBox(height: isTablet ? 40 : 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailField(BuildContext context, bool isTablet) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
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
          TextFormField(
            controller: emailCtrl,
            focusNode: _emailFocusNode,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) {
              FocusScope.of(context).requestFocus(_passwordFocusNode);
            },
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'valid_required'.tr;
              }

              // Check for invalid characters
              final validCharsRegex = RegExp(r'^[a-zA-Z0-9.]+$');
              if (!validCharsRegex.hasMatch(v)) {
                return 'Only letters, numbers, and dots are allowed'.tr;
              }

              return null;
            },
            onChanged: (value) {
              // Remove any pasted domain suffix
              if (value.contains('@')) {
                final username = value.split('@')[0];
                emailCtrl.text = username;
                emailCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: username.length),
                );
              }

              // Remove any spaces
              if (value.contains(' ')) {
                final noSpaces = value.replaceAll(' ', '');
                emailCtrl.text = noSpaces;
                emailCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: noSpaces.length),
                );
              }
            },
            decoration: InputDecoration(
              fillColor: Colors.white,
              filled: true,
              prefixIcon: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                height: 2,
                width: 2,
                child: Image.asset("assets/png/mail.png"),
              ),
              suffixText: WText.emailSuffix,
              suffixStyle: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
              contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              hintText: 'email'.tr,
              errorStyle: TextStyle(
                height: 1,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
              hintStyle: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w400,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _isEmailValid ? Colors.grey.shade300 : Colors.red.shade300,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.red.shade400,
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.red.shade400,
                  width: 2,
                ),
              ),
            ),
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
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

  Widget _buildPasswordField(BuildContext context, bool isTablet) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
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
      child: TextFormField(
        controller: passwordCtrl,
        focusNode: _passwordFocusNode,
        obscureText: _obscurePassword,
        validator: (v) {
          if (v == null || v.isEmpty) {
            return 'valid_password'.tr;
          } else if (v.length < 6) {
            return 'password_must_be_at_least_8_characters'.tr;
          }
          return null;
        },
        decoration: InputDecoration(
          fillColor: Colors.white,
          filled: true,
          prefixIcon: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            height: 2,
            width: 2,
            child: Image.asset('assets/png/lock.png'),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: Colors.grey.shade600,
              size: 22,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
          contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          hintText: 'password'.tr,
          errorStyle: TextStyle(
            height: 1,
            color: Colors.red.shade700,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(
            fontSize: isTablet ? 16 : 14,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w400,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Theme.of(context).primaryColor,
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.red.shade400,
              width: 1.5,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.red.shade400,
              width: 2,
            ),
          ),
        ),
        style: TextStyle(
          fontSize: isTablet ? 16 : 14,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
