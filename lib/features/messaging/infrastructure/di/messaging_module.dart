import 'package:injectable/injectable.dart';
import 'package:get_storage/get_storage.dart';
import 'package:enough_mail/enough_mail.dart' as em;

import 'package:wahda_bank/features/messaging/domain/repositories/message_repository.dart';
import 'package:wahda_bank/features/messaging/infrastructure/datasources/local_store.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';
import 'package:wahda_bank/features/messaging/infrastructure/repositories_impl/imap_message_repository.dart';
import 'package:wahda_bank/features/messaging/infrastructure/datasources/outbox_dao.dart';
import 'package:wahda_bank/features/messaging/infrastructure/datasources/draft_dao.dart';
import 'package:wahda_bank/features/messaging/infrastructure/repositories_impl/outbox_repository_impl.dart';
import 'package:wahda_bank/features/messaging/infrastructure/repositories_impl/draft_repository_impl.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/smtp_gateway.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/outbox_repository.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/draft_repository.dart';

@module
abstract class MessagingModule {
  @LazySingleton()
  MessageRepository provideMessageRepository(ImapGateway gateway, LocalStore store) {
    final box = GetStorage();
    final accountId = (box.read('email') as String?) ?? 'default-account';
    return ImapMessageRepository(accountId: accountId, gateway: gateway, store: store);
  }

  @LazySingleton()
  LocalStore provideLocalStore() => InMemoryLocalStore();

  @LazySingleton()
  ImapGateway provideImapGateway() {
    // Construct a MailClient using the same manual settings as legacy MailService.
    final box = GetStorage();
    final email = (box.read('email') as String?) ?? '';
    final password = (box.read('password') as String?) ?? '';

    final account = em.MailAccount.fromManualSettings(
      name: email,
      email: email,
      incomingHost: 'wbmail.wahdabank.com.ly',
      outgoingHost: 'wbmail.wahdabank.com.ly',
      password: password,
      incomingType: em.ServerType.imap,
      outgoingType: em.ServerType.smtp,
      incomingPort: 43245,
      outgoingPort: 43244,
      incomingSocketType: em.SocketType.ssl,
      outgoingSocketType: em.SocketType.plain,
      userName: email,
      outgoingClientDomain: 'wahdabank.com.ly',
    );
    final client = em.MailClient(account);
    return EnoughImapGateway(client);
  }

  // P4: Outbox/Drafts/SMTP registrations (infra only).
  @LazySingleton()
  OutboxDao provideOutboxDao() => InMemoryOutboxDao();

  @LazySingleton()
  DraftDao provideDraftDao() => InMemoryDraftDao();

  @LazySingleton()
  OutboxRepository provideOutboxRepository(OutboxDao dao) => OutboxRepositoryImpl(dao);

  @LazySingleton()
  DraftRepository provideDraftRepository(DraftDao dao) => DraftRepositoryImpl(dao);

  @LazySingleton()
  SmtpGateway provideSmtpGateway() => EnoughSmtpGateway();
}
