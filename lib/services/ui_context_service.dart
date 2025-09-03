import 'package:get/get.dart';

/// Tracks UI context/state so services can adjust behavior.
/// - isAppForeground: whether the app is currently in the foreground
/// - inboxVisible: whether the inbox/home email list is currently visible to the user
class UiContextService extends GetxService {
  static UiContextService? _instance;
  static UiContextService get instance => _instance ??= UiContextService._();

  UiContextService._();

  final RxBool _isAppForeground = true.obs;
  final RxBool _inboxVisible = false.obs;

  bool get isAppForeground => _isAppForeground.value;
  bool get inboxVisible => _inboxVisible.value;

  set isAppForeground(bool v) => _isAppForeground.value = v;
  set inboxVisible(bool v) => _inboxVisible.value = v;
}
