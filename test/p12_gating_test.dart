import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/shared/di/injection.dart';
import 'package:wahda_bank/shared/ddd_ui_wiring.dart';
import 'package:wahda_bank/widgets/search/controllers/mail_search_controller.dart';
import 'package:wahda_bank/views/compose/controller/compose_controller.dart';
import 'package:wahda_bank/services/mail_service.dart';

const MethodChannel _pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Mock path_provider for GetStorage in tests
    _pathProviderChannel.setMockMethodCallHandler((MethodCall methodCall) async {
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

    final ctrl = MailSearchController();
    ctrl.searchController.text = 'query';

    final handled = await DddUiWiring.maybeSearch(controller: ctrl);
    expect(handled, false);
  });

  test('Search routes to DDD when enabled and kill switch off', () async {
    final box = GetStorage();
    await box.write('ddd.kill_switch.enabled', false);
    await box.write('ddd.search.enabled', true);

    final ctrl = MailSearchController();
    ctrl.searchController.text = 'test';
    final handled = await DddUiWiring.maybeSearch(controller: ctrl);
    expect(handled, true);
  });

  test('Default flags off -> legacy path (search)', () async {
    final box = GetStorage();
    await box.write('ddd.kill_switch.enabled', false);
    await box.write('ddd.search.enabled', false);

    final ctrl = MailSearchController();
    ctrl.searchController.text = 'test';
    final handled = await DddUiWiring.maybeSearch(controller: ctrl);
    expect(handled, false);
  });

  test('Send routes to DDD when enabled and kill switch off', () async {
    final box = GetStorage();
    await box.write('ddd.kill_switch.enabled', false);
    await box.write('ddd.send.enabled', true);

    final compose = ComposeController();
    final handled = await DddUiWiring.maybeSendFromCompose(controller: compose, builtMessage: null);
    expect(handled, true);
  });

  test('Default flags off -> legacy path (send)', () async {
    final box = GetStorage();
    await box.write('ddd.kill_switch.enabled', false);
    await box.write('ddd.send.enabled', false);

    final compose = ComposeController();
    final handled = await DddUiWiring.maybeSendFromCompose(controller: compose, builtMessage: null);
    expect(handled, false);
  });
}

