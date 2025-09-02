import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import '../app/controllers/settings_controller.dart';

class SecurityService extends GetxService {
  static SecurityService get instance => Get.find<SecurityService>();

  final LocalAuthentication _localAuth = LocalAuthentication();
  late final SettingController _settingsController;

  // App state tracking
  DateTime? _lastActive;

  // Initialize the service
  Future<SecurityService> init() async {
    // Get the settings controller
    _settingsController = Get.find<SettingController>();

    // Set up app lifecycle observer
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver(this));
    return this;
  }

  // Check if biometrics are available
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting biometrics: $e');
      }
      return [];
    }
  }

  // Determine if face recognition is available
  Future<bool> isFaceRecognitionAvailable() async {
    try {
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics.contains(BiometricType.face) ||
          availableBiometrics.contains(BiometricType.strong) ||
          availableBiometrics.contains(BiometricType.weak);
    } catch (e) {
      if (kDebugMode) {
        print('Error checking face recognition: $e');
      }
      return false;
    }
  }

  // Authenticate with biometrics - enhanced to prioritize face recognition
  Future<bool> authenticateWithBiometrics() async {
    try {
      final canAuthenticate = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canAuthenticate || !isDeviceSupported) {
        return false;
      }

      // Get available biometrics to determine the best prompt
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      final hasFaceId =
          availableBiometrics.contains(BiometricType.face) ||
          availableBiometrics.contains(BiometricType.strong);

      // Customize the authentication prompt based on available biometrics
      final String localizedReason =
          hasFaceId
              ? 'Authenticate with Face ID to access your emails'
              : 'Authenticate with biometrics to access your emails';

      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          // Setting useErrorDialogs to true ensures system handles error presentation
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error authenticating with biometrics: $e');
      }
      // Handle specific error cases
      if (e is PlatformException) {
        if (e.code == auth_error.notAvailable ||
            e.code == auth_error.notEnrolled ||
            e.code == auth_error.passcodeNotSet) {
          // Fall back to system authentication if biometrics aren't available
          return await authenticateWithSystem();
        }
      }
      return false;
    }
  }

  // Authenticate with system (PIN, pattern, etc.)
  Future<bool> authenticateWithSystem() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your emails',
        options: const AuthenticationOptions(
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error authenticating with system: $e');
      }
      return false;
    }
  }

  // Handle app going to background
  void onAppBackground() {
    _lastActive = DateTime.now();

    // If app lock is enabled, mark as locked
    if (_settingsController.appLock.value) {
      _settingsController.isAuthenticated.value = false;
    }
  }

  // Handle app coming to foreground
  Future<void> onAppForeground() async {
    // If app lock is enabled, check if we need to authenticate
    if (_settingsController.appLock.value &&
        !_settingsController.isAuthenticated.value) {
      // Check if we need to authenticate based on timing
      if (_shouldLockBasedOnTiming()) {
        // Show authentication screen
        Get.toNamed('/auth');
      } else {
        // Auto-unlock if timing hasn't been reached
        _settingsController.isAuthenticated.value = true;
      }
    }
  }

  // Determine if app should lock based on auto-lock timing setting
  bool _shouldLockBasedOnTiming() {
    if (_lastActive == null) return true;

    final timing = _settingsController.autoLockTiming.value;
    final now = DateTime.now();
    final difference = now.difference(_lastActive!);

    switch (timing) {
      case 'immediate':
        return true;
      case '1min':
        return difference.inMinutes >= 1;
      case '5min':
        return difference.inMinutes >= 5;
      case '15min':
        return difference.inMinutes >= 15;
      case '30min':
        return difference.inMinutes >= 30;
      case '1hour':
        return difference.inMinutes >= 60;
      default:
        return true;
    }
  }

  // Lock the app manually
  void lockApp() {
    _settingsController.isAuthenticated.value = false;
    Get.toNamed('/auth');
  }

  // Unlock the app
  Future<bool> unlockApp() async {
    final lockMethod = _settingsController.lockMethod.value;
    bool authenticated = false;

    if (lockMethod == 'biometric') {
      authenticated = await authenticateWithBiometrics();
      // Fall back to system auth if biometrics fail
      if (!authenticated) {
        authenticated = await authenticateWithSystem();
      }
    } else {
      // PIN or pattern uses system authentication
      authenticated = await authenticateWithSystem();
    }

    _settingsController.isAuthenticated.value = authenticated;
    return authenticated;
  }
}

// App lifecycle observer to detect foreground/background transitions
class _AppLifecycleObserver with WidgetsBindingObserver {
  final SecurityService _securityService;

  _AppLifecycleObserver(this._securityService);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _securityService.onAppBackground();
    } else if (state == AppLifecycleState.resumed) {
      _securityService.onAppForeground();
    }
  }
}
