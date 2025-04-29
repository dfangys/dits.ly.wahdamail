import 'dart:io';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:clipboard/clipboard.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:otp_autofill/otp_autofill.dart';
import 'package:otp_text_field/otp_text_field.dart';
import 'package:otp_text_field/style.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
import 'package:telephony/telephony.dart';
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
  Telephony telephony = Telephony.instance;
  final otpController = OtpFieldController();
  final TextEditingController passwordController = TextEditingController();
  RoundedLoadingButtonController controller = RoundedLoadingButtonController();
  final formKey = GlobalKey<FormState>();
  String otpPin = '';

  // autofill otp
  late OTPTextEditController autoFillOtpController;
  late OTPInteractor _otpInteractor;

  @override
  void initState() {
    listenForSms();
    super.initState();
  }

  Future listenForSms() async {
    _initInteractor();
    if (Platform.isAndroid) {
      bool? permissionsGranted = await telephony.requestSmsPermissions;
      if (permissionsGranted != null && permissionsGranted) {
        telephony.listenIncomingSms(
          onNewMessage: (SmsMessage message) {
            onSmsReceived(message.body);
          },
          listenInBackground: false,
        );
      }
    } else if (Platform.isIOS) {
      autoFillOtpController = OTPTextEditController(
        codeLength: 5,
        onCodeReceive: (code) {
          onSmsReceived(code);
        },
        otpInteractor: _otpInteractor,
        onTimeOutException: () {
          autoFillOtpController.startListenUserConsent(
            (code) {
              final exp = RegExp(r'(\d{5})');
              return exp.stringMatch(code ?? '') ?? '';
            },
            strategies: [
              // SampleStrategy(),
            ],
          );
        },
      )..startListenUserConsent(
          (code) {
            final exp = RegExp(r'(\d{5})');
            return exp.stringMatch(code ?? '') ?? '';
          },
          strategies: [
            // TimeoutStrategy(),
          ],
        );
    }
  }

  Future<void> _initInteractor() async {
    _otpInteractor = OTPInteractor();
    // You can receive your app signature by using this method.
    final appSignature = await _otpInteractor.getAppSignature();
    if (kDebugMode) {
      print('Your app signature: $appSignature');
    }
  }

  void onSmsReceived(String? message) {
    if (message != null) {
      var match = RegExp(r'\d{5}').firstMatch(message);
      if (match != null) {
        String numCode = match.group(0) ?? '';
        otpController.set(numCode.split(''));
        otpPin = numCode;
      }
    }
  }

  final appApi = Get.find<AppApi>();

  Future verifyOtp() async {
    if (formKey.currentState!.validate()) {
      try {
        var data = await appApi.resetPassword(
          widget.email,
          passwordController.text,
          otpPin,
        );
        if (data is Map && mounted) {
          if (data.containsKey('verified') && data['verified']) {
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
            AwesomeDialog(
              context: context,
              dialogType: DialogType.error,
              title: 'error'.tr,
              desc: data['message'] ?? 'msg_some_thing_went_wrong'.tr,
            ).show();
          }
        } else if (mounted) {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.error,
            title: 'Error',
            desc: data['message'] ?? 'msg_some_thing_went_wrong'.tr,
          ).show();
        }
      } on AppApiException catch (e) {
        if (mounted) {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.error,
            title: 'error'.tr,
            desc: e.message,
          ).show();
        }
      } catch (e) {
        if (mounted) {
          AwesomeDialog(
            context: context,
            dialogType: DialogType.error,
            title: 'error'.tr,
            desc: e.toString(),
          ).show();
        }
      }
    }
  }

  Future resendSms() async {
    try {
      String email = widget.email;
      var res = await appApi.sendResetPasswordOtp(email);
      if (res is Map && res.isNotEmpty) {
        if (res.containsKey('otp_send') && res['otp_send']) {
          Get.to(
            () => VerifyResetPasswordOtpScreen(email: email),
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
          btnCancelOnPress: () {},
        ).show();
      }
    } finally {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Column(
        children: [
          const SizedBox(height: WSizes.imageThumbSize),
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
          const SizedBox(height: WSizes.spaceBtwSections),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Row(
                      children: [
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
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "msg_enter_and_password".tr,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      width: 60,
                      height: 6,
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const Text(
                      WText.verifyText,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    _buildOtpField(context),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: resendSms,
                            child: Text('resend_otp'.tr),
                          )
                        ],
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.of(context).size.width - 40,
                      child: Form(
                        key: formKey,
                        child: WTextFormField(
                          controller: passwordController,
                          icon: Icon(Iconsax.lock_1),
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
                    const Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 5,
                          ),
                          child: Text(
                            WText.verifyText2,
                            textAlign: TextAlign.start,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 50,
                      width: MediaQuery.of(context).size.width - 50,
                      child: WRoundedButton(
                        controller: controller,
                        onPress: () {
                          verifyOtp();
                        },
                        text: 'reset_password'.tr,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpField(BuildContext context) {
    // if (Platform.isIOS) {
    //   return TextFormField(
    //     controller: autoFillOtpController,
    //     keyboardType: TextInputType.number,
    //     maxLength: 5,
    //     textAlign: TextAlign.center,
    //     style: const TextStyle(fontSize: 17),
    //     decoration: InputDecoration(
    //       contentPadding: const EdgeInsets.all(10),
    //       hintText: 'Enter OTP',
    //       hintStyle: const TextStyle(fontSize: 17),
    //       border: OutlineInputBorder(
    //         borderRadius: BorderRadius.circular(10),
    //         borderSide: const BorderSide(color: Colors.white),
    //       ),
    //     ),
    //     onFieldSubmitted: (value) {
    //       otpPin = value;
    //       verifyOtp();
    //     },
    //     onSaved: (value) {
    //       if (value != null) otpPin = value;
    //       verifyOtp();
    //     },
    //   );
    // }
    return OTPTextField(
      length: 5,
      width: MediaQuery.of(context).size.width * 0.8,
      fieldWidth: 50,
      style: const TextStyle(fontSize: 17),
      textFieldAlignment: MainAxisAlignment.spaceAround,
      fieldStyle: FieldStyle.box,
      controller: otpController,
      otpFieldStyle: OtpFieldStyle(
        backgroundColor: Colors.white,
      ),
      onCompleted: (pin) {
        otpPin = pin;
        verifyOtp();
      },
      onChanged: (value) async {
        if (Platform.isIOS && value.length == 1) {
          String clipboardText = await FlutterClipboard.paste();
          onSmsReceived(clipboardText);
        }
      },
    );
  }

  @override
  void dispose() {
    if (Platform.isIOS) {
      autoFillOtpController.dispose();
    }
    super.dispose();
  }
}
