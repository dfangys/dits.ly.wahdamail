import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  Directory _tmp = Directory.systemTemp.createTempSync('wahda_test_');
  @override
  Future<String?> getApplicationDocumentsPath() async => _tmp.path;
  @override
  Future<String?> getApplicationSupportPath() async => _tmp.path;
  @override
  Future<String?> getTemporaryPath() async => _tmp.path;
}

FutureOr<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = _FakePathProvider();

  // Also stub method channels used by older path_provider implementations.
  final tmp = Directory.systemTemp.createTempSync('wahda_test_');
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  // Some platforms use platform-specific channels; stub common ones.
  const channelMacOS = MethodChannel('plugins.flutter.io/path_provider_macos');
  Future<dynamic> handler(MethodCall call) async {
    switch (call.method) {
      case 'getTemporaryDirectory':
      case 'getApplicationDocumentsDirectory':
      case 'getApplicationSupportDirectory':
      case 'getLibraryDirectory':
      case 'getDownloadsDirectory':
        return tmp.path;
      case 'getExternalStorageDirectories':
      case 'getExternalCacheDirectories':
        return [tmp.path];
      default:
        return tmp.path;
    }
  }
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, handler);
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channelMacOS, handler);

  // Keep storage local to tests; avoids platform IO
  await GetStorage.init('test');
  await testMain();
}

