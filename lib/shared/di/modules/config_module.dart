import 'package:injectable/injectable.dart';
import 'package:wahda_bank/shared/config/app_config.dart';

@module
abstract class ConfigModule {
  @lazySingleton
  AppConfig appConfig() {
    const base = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://chase.com.ly',
    );
    return const AppConfig(apiBaseUrl: base);
  }
}

