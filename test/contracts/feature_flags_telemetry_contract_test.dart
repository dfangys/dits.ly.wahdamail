import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter/services.dart';
import 'package:wahda_bank/services/feature_flags.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Stub path_provider channels for get_storage
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    const channelMacOS = MethodChannel(
      'plugins.flutter.io/path_provider_macos',
    );
    final tmp = Directory.systemTemp.createTempSync('wahda_test_');
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
    // Initialize both default and test boxes
    await GetStorage.init();
    await GetStorage.init('test');
  });
  group('Feature flags + telemetry baseline', () {
    test('telemetryPath defaults to legacy when DDD flags are off', () {
      // By default storage is empty; DDD flags should be false
      expect(FeatureFlags.telemetryPath, equals('legacy'));
    });
  });
}
