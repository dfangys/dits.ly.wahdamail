import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../app/controllers/settings_controller.dart';

class AuthMiddleware extends GetMiddleware {
  final SettingController _settingsController = Get.find<SettingController>();

  @override
  RouteSettings? redirect(String? route) {
    // If app lock is enabled and user is not authenticated, redirect to auth screen
    if (_settingsController.appLock.value &&
        !_settingsController.isAuthenticated.value) {
      return const RouteSettings(name: '/auth');
    }
    return null;
  }
}
