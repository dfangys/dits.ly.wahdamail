import 'package:get_storage/get_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:wahda_bank/shared/di/injection.dart';

/// Lightweight DI bootstrap helper for tests that touch auth flows.
/// - Initializes GetStorage
/// - Calls configureDependencies() with a test environment if desired
import 'package:get_it/get_it.dart';
import 'package:wahda_bank/features/auth/application/auth_usecase.dart';

Future<void> configureDependenciesForTests({String env = Environment.test}) async {
  try {
    await GetStorage.init();
  } catch (_) {}
  await configureDependencies(env: env);
  assert(GetIt.I.isRegistered<AuthUseCase>(), 'AuthUseCase not registered in test DI');
}

