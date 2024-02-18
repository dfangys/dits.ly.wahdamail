import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:otp_text_field/otp_text_field.dart';
import 'package:telephony/telephony.dart';
import 'package:wahda_bank/app/apis/app_api.dart';
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
          listenForSms();
        }
      } else {
        AwesomeDialog(
          context: Get.context!,
          dialogType: DialogType.success,
          title: 'Error',
          desc: data['message'] ?? 'Something went wrong',
        ).show();
      }
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
    telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        if (kDebugMode) {
          print('New incoming message: ${message.address} - ${message.body}');
        }
        onSmsReceived(message.body);
      },
      onBackgroundMessage: (message) {
        if (kDebugMode) {
          print('OnBackground message: ${message.address} - ${message.body}');
        }
      },
    );
  }

  void onSmsReceived(String? message) {
    if (message != null) {
      String num = message.replaceAll(RegExp(r'[^0-9]'), '');
      List<String> code = [];
      for (var i = 0; i < num.length; i++) {
        code[i] = num[i];
      }
      fieldController.set(code);
    }
  }

  Future verifyPhoneOtp(String otp) async {
    try {
      var data = await appApi.verifyOp(otp);
      if (data is Map && data.containsKey('verified') && data['verified']) {
        await _storage.write('otp', true);
        Get.offAll(() => const LoadingFirstView());
      } else {
        AwesomeDialog(
          context: Get.context!,
          dialogType: DialogType.error,
          title: 'Error',
          desc: data['message'] ?? 'Something went wrong',
        ).show();
      }
    } catch (e) {
      AwesomeDialog(
        context: Get.context!,
        dialogType: DialogType.error,
        title: 'Error',
        desc: e.toString(),
      ).show();
    }
  }
}
