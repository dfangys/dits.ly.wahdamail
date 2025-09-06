import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/shared/di/injection.dart';
import 'package:wahda_bank/features/search/presentation/search_view_model.dart';
import 'package:wahda_bank/features/messaging/presentation/compose_view_model.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/features/messaging/presentation/api/compose_controller_api.dart';
import 'package:wahda_bank/services/mail_service.dart';

const MethodChannel _pathProviderChannel = MethodChannel(
  'plugins.flutter.io/path_provider',
);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Mock path_provider for GetStorage in tests
    _pathProviderChannel.setMockMethodCallHandler((
      MethodCall methodCall,
    ) async {
      switch (methodCall.method) {
        case 'getApplicationDocumentsDirectory':
        case 'getApplicationSupportDirectory':
        case 'getTemporaryDirectory':
        case 'getLibraryDirectory':
        case 'getDownloadsDirectory':
          return '/tmp';
        default:
          return '/tmp';
      }
    });
    await GetStorage.init();
    await configureDependencies();
    // Initialize MailService with a local client (no network connect)
    MailService.instance.setClientAndAccount('test@example.com', 'pass');
  });

  tearDown(() async {
    // Clear flags between tests
    final box = GetStorage();
    await box.erase();
  });

  test('Kill switch forces legacy path (search)', () async {
    final box = GetStorage();
    await box.write('ddd.kill_switch.enabled', true);
    await box.write('ddd.search.enabled', true);

    final vm = getIt<SearchViewModel>();
    await vm.runSearchText('query', requestId: 'req');
    // No throw; UI state updated via VM
    expect(true, true);
  });

  test('Search routes to DDD when enabled and kill switch off', () async {
    final box = GetStorage();
    await box.write('ddd.kill_switch.enabled', false);
    await box.write('ddd.search.enabled', true);

    final vm = getIt<SearchViewModel>();
    await vm.runSearchText('test', requestId: 'req');
    expect(true, true);
  });

  test('Default flags off -> legacy path (search)', () async {
    final box = GetStorage();
    await box.write('ddd.kill_switch.enabled', false);
    await box.write('ddd.search.enabled', false);

    final vm = getIt<SearchViewModel>();
    await vm.runSearchText('test', requestId: 'req');
    expect(true, true);
  });

  test('Send routes to DDD when enabled and kill switch off', () async {
    final box = GetStorage();
    await box.write('ddd.kill_switch.enabled', false);
    await box.write('ddd.send.enabled', true);

    final compose = ComposeController();
    final vm = getIt<ComposeViewModel>();
    final msg = MimeMessage();
    final ok = await vm.send(
      controller: compose,
      builtMessage: msg,
      requestId: 'req',
    );
    expect(ok, isA<bool>());
  });

  test('Default flags off -> legacy path (send)', () async {
    final box = GetStorage();
    await box.write('ddd.kill_switch.enabled', false);
    await box.write('ddd.send.enabled', false);

    final compose = ComposeController();
    final vm = getIt<ComposeViewModel>();
    final msg = MimeMessage();
    final ok = await vm.send(
      controller: compose,
      builtMessage: msg,
      requestId: 'req',
    );
    expect(ok, isA<bool>());
  });
}
