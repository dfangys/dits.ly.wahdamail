import 'package:injectable/injectable.dart';
import 'package:wahda_bank/infrastructure/api/mailsys_api_client.dart';

@module
abstract class ApiModule {
  @lazySingleton
  MailsysApiClient mailsysApiClient() => MailsysApiClient();
}

