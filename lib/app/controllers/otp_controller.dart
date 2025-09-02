import 'dart:io';
import 'dart:async';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:otp_autofill/otp_autofill.dart';
import 'package:otp_text_field/otp_text_field.dart';
import 'package:telephony/telephony.dart';
import 'package:wahda_bank/infrastructure/api/mailsys_api_client.dart';
import 'package:wahda_bank/views/authantication/screens/login/login.dart';
import 'package:wahda_bank/views/authantication/screens/otp/enter_otp/enter_otp.dart';
import 'package:wahda_bank/views/view/screens/first_loading_view.dart';

class OtpController extends GetxController {
  final MailsysApiClient api = Get.find<MailsysApiClient>();
  final _storage = GetStorage();

  final Telephony telephony = Telephony.instance;

  //
  OtpFieldController fieldController = OtpFieldController();
  RxBool isError = false.obs;
  RxBool isSuccess = false.obs;
  // Latest masked phone for OTP notifications (login flow)
  final RxString maskedPhone = ''.obs;

  // Prevent multiple submissions and control resend cooldown
  final RxBool isRequestingOtp = false.obs;
  final RxInt resendSeconds = 0.obs;
  Timer? _resendTimer;
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
    if (isRequestingOtp.value) return;
    try {
      isRequestingOtp.value = true;
      isError(false);
      final email = _storage.read('email');
      final password = _storage.read('password');
      if (email == null || password == null) {
        throw Exception('Missing stored credentials');
      }
      final res = await api.login(email.toString(), password.toString());
      final data = res['data'] as Map<String, dynamic>?;
      final requiresOtp = data?['requires_otp'] == true;
      final token = data?['token'] as String?;

      if (requiresOtp) {
        isSuccess(true);
        // capture masked phone if provided by backend
        final mp = data?['masked_phone'];
        if (mp is String) maskedPhone.value = mp;
        // start 60s cooldown for resend
        startResendCountdown(60);
        if (Platform.isAndroid) {
          listenForSms();
        } else if (Platform.isIOS) {
          // iOS clipboard auto-fill handled in EnterOtpScreen
        }
        Get.to(() => EnterOtpScreen());
      } else if (token != null && token.isNotEmpty) {
        await _storage.write('otp', true);
        Get.offAll(() => const LoadingFirstView());
      } else {
        AwesomeDialog(
          context: Get.context!,
          dialogType: DialogType.error,
          title: 'Error',
          desc: res['message']?.toString() ?? 'Something went wrong',
        ).show();
      }
    } on MailsysApiException catch (e) {
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
    } finally {
      isRequestingOtp.value = false;
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

  void startResendCountdown(int seconds) {
    // Cancel any existing timer
    _resendTimer?.cancel();
    resendSeconds.value = seconds;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (resendSeconds.value <= 1) {
        t.cancel();
        resendSeconds.value = 0;
      } else {
        resendSeconds.value = resendSeconds.value - 1;
      }
    });
  }

  Future resendOtp() async {
    // Only allow when cooldown ended and not already requesting
    if (resendSeconds.value > 0 || isRequestingOtp.value) return;
    await requestOtp();
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
      final email = _storage.read('email');
      if (email == null) {
        throw Exception('Missing stored email');
      }
      final res = await api.verifyOtp(email.toString(), otp ?? otpPin);
      final data = res['data'] as Map<String, dynamic>?;
      final token = data?['token'] as String?;
      if (token != null && token.isNotEmpty) {
        // Persist mailbox metadata if present
        final mailbox = data?['mailbox'];
        if (mailbox is Map) {
          await _storage.write('mailsys_mailbox', mailbox);
        }
        await _storage.write('otp', true);
        Get.offAll(() => const LoadingFirstView());
      } else {
        AwesomeDialog(
          context: Get.context!,
          dialogType: DialogType.error,
          title: 'error'.tr,
          desc: res['message']?.toString() ?? 'Something went wrong',
          btnOkText: 'Ok',
          btnOkColor: Theme.of(Get.context!).primaryColor,
        ).show();
        fieldController.clear();
      }
    } on MailsysApiException catch (e) {
      AwesomeDialog(
        context: Get.context!,
        dialogType: DialogType.error,
        title: 'error'.tr,
        desc: e.message,
      ).show();
      fieldController.clear();
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

  @override
  void onClose() {
    _resendTimer?.cancel();
    super.onClose();
  }

  Future logout() async {
    await _storage.erase();
    Get.offAll(() => const LoginScreen());
  }
}
