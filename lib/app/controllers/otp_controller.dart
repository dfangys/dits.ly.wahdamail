import 'dart:io';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
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

  Future requestOtp() async {
    try {
      var data = await appApi.requestOtp();
      if (data is Map) {
        if (data.containsKey('white_list') && data['white_list']) {
          // set authorized and Goto Home
          await _storage.write('otp', true);
          Get.offAll(() => const LoadingFirstView());
        } else if (data.containsKey('otp_send') && data['otp_send']) {
          // goto otp verifiy view
          if (Platform.isAndroid) {
            listenForSms();
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
    } catch (e) {
      AwesomeDialog(
        context: Get.context!,
        dialogType: DialogType.error,
        title: 'Error',
        desc: e.toString(),
      ).show();
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

  void onSmsReceived(String? message) {
    if (message != null) {
      var match = RegExp(r'\d{5}').firstMatch(message);
      if (match != null) {
        printInfo(info: match.group(0) ?? '');
        String numCode = match.group(0) ?? '';
        fieldController.set(numCode.split(''));
        otpPin = numCode;
      }
    }
  }

  String otpPin = '';

  Future verifyPhoneOtp({String? otp}) async {
    try {
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
      }
    } catch (e) {
      AwesomeDialog(
        context: Get.context!,
        dialogType: DialogType.error,
        title: 'error'.tr,
        desc: e.toString(),
      ).show();
    }
  }

  Future logout() async {
    await _storage.erase();
    Get.offAll(() => LoginScreen());
  }
}
