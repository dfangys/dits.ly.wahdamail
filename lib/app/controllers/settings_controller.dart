import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../../views/settings/data/swap_data.dart';

class SettingController extends GetxController {
  final language = 'English'.obs;
  final readReceipts = 'Off'.obs;
  final security = 'Off'.obs;
  final swipeGesturesLTR = 'read_unread'.obs;
  final swipeGesturesRTL = 'delete'.obs;
  final signature = ''.obs;
  final signatureReply = true.obs;
  final signatureForward = true.obs;
  final signatureNewMessage = true.obs;
  final accountName = ''.obs;

  SwapActionModel get swipeGesturesLTRModel => SwapSettingData()
      .swapActionModel[getSwapActionFromString(swipeGesturesLTR.value)]!;

  SwapActionModel get swipeGesturesRTLModel => SwapSettingData()
      .swapActionModel[getSwapActionFromString(swipeGesturesRTL.value)]!;

  @override
  void onInit() {
    loadLocalSettings();
    ever(language, (v) => box.write('language', v));
    ever(readReceipts, (v) => box.write('readReceipts', v));
    ever(security, (v) => box.write('security', v));
    ever(swipeGesturesLTR, (v) => box.write('swipeGesturesLTR', v));
    ever(swipeGesturesRTL, (v) => box.write('swipeGesturesRTL', v));
    ever(signature, (v) => box.write('signature', v));
    ever(signatureReply, (v) => box.write('signatureReply', v));
    ever(signatureForward, (v) => box.write('signatureForward', v));
    ever(signatureNewMessage, (v) => box.write('signatureNewMessage', v));
    ever(accountName, (v) => box.write('accountName', v));
    super.onInit();
  }

  // Flutter Storage for local settings
  final box = GetStorage();

  Future loadLocalSettings() async {
    language.value = box.read('language') ?? 'English';
    readReceipts.value = box.read('readReceipts') ?? 'Off';
    security.value = box.read('security') ?? 'Off';
    swipeGesturesLTR.value = box.read('swipeGesturesLTR') ?? 'readUnread';
    swipeGesturesRTL.value = box.read('swipeGesturesRTL') ?? 'delete';
    signature.value = box.read('signature') ?? '';
    signatureReply.value = box.read('signatureReply') ?? true;
    signatureForward.value = box.read('signatureForward') ?? true;
    signatureNewMessage.value = box.read('signatureNewMessage') ?? true;
    accountName.value = box.read('accountName') ?? '';
  }
}
