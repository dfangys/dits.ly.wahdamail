import 'package:injectable/injectable.dart';
import 'package:wahda_bank/services/mail_service.dart';

/// Slim application-layer adapter exposing only what presentation needs for first run.
@lazySingleton
class FirstRunUseCase {
  FirstRunUseCase();

  Future<void> init() => MailService.instance.init();
  Future<void> connect() => MailService.instance.connect();
  Future<List<dynamic>> listMailboxes() =>
      MailService.instance.client.listMailboxes();
}

