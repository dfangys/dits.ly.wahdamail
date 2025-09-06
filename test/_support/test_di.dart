import 'package:get_storage/get_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:wahda_bank/shared/di/injection.dart';

/// Lightweight DI bootstrap helper for tests that touch auth flows.
/// - Initializes GetStorage
/// - Calls configureDependencies() with a test environment if desired
Future<void> configureDependenciesForTests({String env = Environment.test}) async {
  try {
    await GetStorage.init();
  } catch (_) {}
  await configureDependencies(env: env);
}

