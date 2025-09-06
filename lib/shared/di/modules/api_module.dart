import 'package:injectable/injectable.dart';
import 'package:wahda_bank/infrastructure/api/mailsys_api_client.dart';
import 'package:wahda_bank/shared/config/app_config.dart';

@module
abstract class ApiModule {
  @lazySingleton
  MailsysApiClient mailsysApiClient(AppConfig cfg) {
    final c = MailsysApiClient();
    // Set base URL at construction to ensure all relative calls resolve
    c.httpClient.baseUrl = cfg.apiBaseUrl;
    return c;
  }
}

