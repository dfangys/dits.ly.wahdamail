import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import 'package:wahda_bank/features/settings/presentation/data/swap_data.dart';
import '../../services/security_service.dart';
import 'package:wahda_bank/infrastructure/api/mailsys_api_client.dart';
import 'package:get_it/get_it.dart';
import 'package:wahda_bank/features/auth/application/auth_usecase.dart';

class SettingController extends GetxController {
  final language = 'en'.obs;
  final readReceipts = false.obs;
  final security = false.obs;
  final swipeGesturesLTR = 'readUnread'.obs;
  final swipeGesturesRTL = 'delete'.obs;
  final signature = ''.obs;
  final signatureReply = true.obs;
  final signatureForward = true.obs;
  final signatureNewMessage = true.obs;
  final accountName = ''.obs;

  final signatureCodeView = false.obs;

  // Remote user profile fields (MailSys API)
  final userName = ''.obs;
  final userEmail = ''.obs;
  final userPhone = ''.obs;
  final quotaLabel = ''.obs;
  final quotaBytes = 0.obs;
  final usageLabel = ''.obs;
  final usagePercent = 0.0.obs;
  final twoFactorEnabled = false.obs;
  final twoFactorUpdating = false.obs;
  final twoFactorStatus = ''.obs; // '', 'success', 'error'

  // Security section properties
  final appLock = false.obs;
  final lockMethod = 'pin'.obs;
  final autoLockTiming = 'immediate'.obs;
  final hideNotificationContent = false.obs;
  final blockRemoteImages = false.obs;
  final enhancedSpamFilter = false.obs;
  final isAuthenticated = true.obs; // Track if user has passed authentication

  SwapActionModel get swipeGesturesLTRModel =>
      SwapSettingData().swapActionModel[getSwapActionFromString(
        swipeGesturesLTR.value,
      )]!;

  SwapActionModel get swipeGesturesRTLModel =>
      SwapSettingData().swapActionModel[getSwapActionFromString(
        swipeGesturesRTL.value,
      )]!;

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

    // Security section ever() calls
    ever(appLock, (v) => box.write('appLock', v));
    ever(lockMethod, (v) => box.write('lockMethod', v));
    ever(autoLockTiming, (v) => box.write('autoLockTiming', v));
    ever(
      hideNotificationContent,
      (v) => box.write('hideNotificationContent', v),
    );
    ever(blockRemoteImages, (v) => box.write('blockRemoteImages', v));
    ever(enhancedSpamFilter, (v) => box.write('enhancedSpamFilter', v));

    super.onInit();
  }

  @override
  void onReady() {
    super.onReady();
    // Fetch profile from API (ignoring errors silently here)
    fetchUserProfile();
  }

  // Flutter Storage for local settings
  final box = GetStorage();

  Future loadLocalSettings() async {
    language.value = box.read('language') ?? 'en';
    readReceipts.value = box.read('readReceipts') ?? false;
    security.value = box.read('security') ?? false;
    final ltr = box.read('swipeGesturesLTR') ?? 'readUnread';
    final rtl = box.read('swipeGesturesRTL') ?? 'delete';
    swipeGesturesLTR.value = _normalizeGesture(ltr);
    swipeGesturesRTL.value = _normalizeGesture(rtl);
    signature.value = box.read('signature') ?? '';
    signatureReply.value = box.read('signatureReply') ?? true;
    signatureForward.value = box.read('signatureForward') ?? true;
    signatureNewMessage.value = box.read('signatureNewMessage') ?? true;
    accountName.value = box.read('accountName') ?? '';

    // Security section settings
    appLock.value = box.read('appLock') ?? false;
    lockMethod.value = box.read('lockMethod') ?? 'pin';
    autoLockTiming.value = box.read('autoLockTiming') ?? 'immediate';
    hideNotificationContent.value =
        box.read('hideNotificationContent') ?? false;
    blockRemoteImages.value = box.read('blockRemoteImages') ?? false;
    enhancedSpamFilter.value = box.read('enhancedSpamFilter') ?? false;
  }

  String _normalizeGesture(String v) {
    final t = v.toString().trim();
    switch (t) {
      case 'read_unread':
        return 'readUnread';
      case 'toggle_flag':
      case 'flag':
        return 'toggleFlag';
      case 'mark_as_junk':
        return 'markAsJunk';
      case 'archive':
      case 'delete':
      case 'readUnread':
      case 'toggleFlag':
      case 'markAsJunk':
        return t; // already canonical
      default:
        return t.isEmpty ? 'readUnread' : t; // safe fallback
    }
  }

  // Authentication methods
  Future<bool> authenticateWithBiometrics() async {
    final securityService = Get.find<SecurityService>();
    return await securityService.authenticateWithBiometrics();
  }

  Future<bool> authenticateWithSystem() async {
    final securityService = Get.find<SecurityService>();
    return await securityService.authenticateWithSystem();
  }

  void lockApp() {
    final securityService = Get.find<SecurityService>();
    securityService.lockApp();
  }

  Future<bool> unlockApp() async {
    final securityService = Get.find<SecurityService>();
    return await securityService.unlockApp();
  }

  // Remote profile
Future<void> fetchUserProfile() async {
    try {
      // Gate unauthenticated calls (no behavior change): skip until token exists
      final hasToken = GetIt.I<AuthUseCase>().hasValidToken();
      if (Get.isLogEnable) {
        // Avoid secrets; only log presence
        // ignore: avoid_print
        print('[Auth] fetchUserProfile gate: tokenPresent=$hasToken');
      }
      if (!hasToken) return;

      final api = Get.find<MailsysApiClient>();
      final res = await api.getUserProfile();
      final data = res['data'] as Map? ?? {};
      final name = data['name']?.toString() ?? '';
      final email = data['email']?.toString() ?? '';
      final phone = data['phone_number']?.toString() ?? '';
      final quota = data['quota'] as Map? ?? {};
      final usage = data['usage'] as Map? ?? {};
      final twofa = data['two_factor_enabled'] == true;

      userName.value = name;
      userEmail.value = email;
      userPhone.value = phone;
      quotaLabel.value = quota['label']?.toString() ?? '';
      quotaBytes.value = (quota['bytes'] is int) ? quota['bytes'] as int : 0;
      usageLabel.value = usage['label']?.toString() ?? '';
      final percent = usage['percent'];
      usagePercent.value = percent is num ? percent.toDouble() : 0.0;
      twoFactorEnabled.value = twofa;

      // Sync accountName with remote name if empty or different
      if (name.isNotEmpty) {
        accountName.value = name;
      }
      // Fallback: if email is missing, try local storage
      userEmail.value =
          userEmail.isNotEmpty
              ? userEmail.value
              : (box.read('email')?.toString() ?? '');
    } catch (_) {
      // Keep silent; UI will show whatever is available (local email/name)
      if (userEmail.isEmpty) {
        userEmail.value = box.read('email')?.toString() ?? '';
      }
    }
  }

  Future<bool> setTwoFactor(bool enabled) async {
    if (twoFactorUpdating.value) return false;
    twoFactorUpdating.value = true;
    try {
      final api = Get.find<MailsysApiClient>();
      final res = await api.updateTwoFactor(enabled: enabled);
      final data = res['data'] as Map? ?? {};
      final twofa = data['two_factor_enabled'] == true;
      twoFactorEnabled.value = twofa;
      twoFactorStatus.value = 'success';
      Future.delayed(const Duration(seconds: 2), () {
        if (!twoFactorUpdating.value) twoFactorStatus.value = '';
      });
      return true;
    } catch (_) {
      twoFactorStatus.value = 'error';
      Future.delayed(const Duration(seconds: 2), () {
        if (!twoFactorUpdating.value) twoFactorStatus.value = '';
      });
      return false;
    } finally {
      twoFactorUpdating.value = false;
    }
  }
}
