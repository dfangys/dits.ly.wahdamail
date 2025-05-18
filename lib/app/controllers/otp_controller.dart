import 'dart:io';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:otp_autofill/otp_autofill.dart';
import 'package:otp_text_field/otp_text_field.dart';
import 'package:telephony/telephony.dart';
import 'package:wahda_bank/app/apis/app_api.dart';
import 'package:wahda_bank/views/authantication/screens/login/login.dart';
import 'package:wahda_bank/views/authantication/screens/otp/enter_otp/enter_otp.dart';
import 'package:wahda_bank/views/view/screens/first_loading_view.dart';

class OtpController extends GetxController {
  final appApi = Get.find<AppApi>();
  final _storage = GetStorage();

  final Telephony telephony = Telephony.instance;

  //
  OtpFieldController fieldController = OtpFieldController();
  RxBool isError = false.obs;
  RxBool isSuccess = false.obs;
  // Future requestOtp() async {
  //   try {
  //     // 🔥 Skip all OTP logic and go straight to Home
  //     await _storage.write('otp', true);
  //     Get.offAll(
  //         () => const HomeScreen()); // ← Use your actual home widget here
  //   } catch (e) {
  //     AwesomeDialog(
  //       context: Get.context!,
  //       dialogType: DialogType.error,
  //       title: 'Error',
  //       desc: e.toString(),
  //     ).show();
  //     isError(true);
  //   }
  // }
  Future requestOtp() async {
    try {
      isError(false);
      var data = await appApi.requestOtp();
      if (data is Map) {
        if (data.containsKey('white_list') && data['white_list']) {
          // set authorized and Goto Home
          await _storage.write('otp', true);
          Get.offAll(() => const LoadingFirstView());
        } else if (data.containsKey('otp_send') && data['otp_send']) {
          // goto otp verifiy view
          isSuccess(true);
          if (Platform.isAndroid) {
            listenForSms();
          } else if (Platform.isIOS) {
            //await _initInteractor();
            //_listenforIosSms();
          }
          Get.to(() => EnterOtpScreen());
        }
      } else {
        AwesomeDialog(
          context: Get.context!,
          dialogType: DialogType.success,
          title: 'Error',
          desc: data['message'] ?? 'Something went wrong',
        ).show();
      }
    } on AppApiException catch (e) {
      AwesomeDialog(
        context: Get.context!,
        dialogType: DialogType.error,
        title: 'error'.tr,
        desc: e.message,
      ).show();
      isError(true);
    } catch (e) {
      AwesomeDialog(
        context: Get.context!,
        dialogType: DialogType.error,
        title: 'Error',
        desc: e.toString(),
      ).show();
      isError(true);
    }
  }
  Future<void> handleIosClipboardPaste() async {
    final data = await Clipboard.getData('text/plain');
    if (data?.text != null && data!.text!.length == 5) {
      otpPin = data.text!;
      verifyPhoneOtp(otp: otpPin);
    }
  }
  Future listenForSms() async {
    bool? permissionsGranted = await telephony.requestSmsPermissions;
    if (permissionsGranted != null && permissionsGranted) {
      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          if (kDebugMode) {
            print('New incoming message: ${message.address} - ${message.body}');
          }
          onSmsReceived(message.body);
        },
        listenInBackground: false,
      );
    }
  }

  // ios listen for sms
  late OTPInteractor _otpInteractor;
  late OTPTextEditController autoFillOtpController;
  Future listenforIosSms() async {
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

  Future<void> initInteractor() async {
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
        printInfo(info: match.group(0) ?? '');
        String numCode = match.group(0) ?? '';
        fieldController.clear();
        fieldController.set(numCode.split(''));
        otpPin = numCode;
      }
    }
  }

  String otpPin = '';
  bool isVerifying = false;

  Future verifyPhoneOtp({String? otp}) async {
    try {
      if (isVerifying) return;
      isVerifying = true;
      var data = await appApi.verifyOp(otp ?? otpPin);
      if (data is Map && data.containsKey('verified') && data['verified']) {
        await _storage.write('otp', true);
        Get.offAll(() => const LoadingFirstView());
      } else {
        AwesomeDialog(
          context: Get.context!,
          dialogType: DialogType.error,
          title: 'error'.tr,
          desc: data['message'] ?? 'Something went wrong',
          btnOkText: 'Ok',
          btnOkColor: Theme.of(Get.context!).primaryColor,
        ).show();
        fieldController.clear();
      }
    } catch (e) {
      AwesomeDialog(
        context: Get.context!,
        dialogType: DialogType.error,
        title: 'error'.tr,
        desc: e.toString(),
      ).show();
      fieldController.clear();
    } finally {
      isVerifying = false;
    }
  }

  Future logout() async {
    await _storage.erase();
    Get.offAll(() => LoginScreen());
  }
}
