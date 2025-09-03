import 'package:injectable/injectable.dart';
import 'package:get_storage/get_storage.dart';
import 'package:enough_mail/enough_mail.dart' as em;

import 'package:wahda_bank/features/messaging/domain/repositories/message_repository.dart';
import 'package:wahda_bank/features/messaging/domain/entities/message.dart';
import 'package:wahda_bank/features/messaging/domain/entities/folder.dart';
import 'package:wahda_bank/features/messaging/domain/entities/attachment.dart';
import 'package:wahda_bank/features/messaging/domain/entities/search_result.dart';
import 'package:wahda_bank/features/messaging/domain/value_objects/search_query.dart';
import 'package:wahda_bank/features/messaging/infrastructure/datasources/local_store.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';
import 'package:wahda_bank/features/messaging/infrastructure/repositories_impl/imap_message_repository.dart';
import 'package:wahda_bank/services/feature_flags.dart';
import 'package:wahda_bank/features/messaging/infrastructure/datasources/outbox_dao.dart';
import 'package:wahda_bank/features/messaging/infrastructure/datasources/draft_dao.dart';
import 'package:wahda_bank/features/messaging/infrastructure/repositories_impl/outbox_repository_impl.dart';
import 'package:wahda_bank/features/messaging/infrastructure/repositories_impl/draft_repository_impl.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/smtp_gateway.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/outbox_repository.dart';
import 'package:wahda_bank/features/messaging/domain/repositories/draft_repository.dart';
import 'package:wahda_bank/features/messaging/infrastructure/threading/thread_builder.dart';
import 'package:wahda_bank/features/messaging/infrastructure/special_use_mapper.dart';
import 'package:wahda_bank/features/messaging/infrastructure/mime/mime_decoder.dart';
import 'package:wahda_bank/features/messaging/infrastructure/sync/uid_window_sync.dart';
import 'package:wahda_bank/features/messaging/infrastructure/flags/flag_conflict_resolver.dart';

@module
abstract class MessagingModule {
  @LazySingleton()
  MessageRepository provideMessageRepository(ImapGateway gateway, LocalStore store) {
    final box = GetStorage();
    final accountId = (box.read('email') as String?) ?? 'default-account';
    return wireMessageRepository(gateway: gateway, store: store, accountId: accountId);
  }

  @LazySingleton()
  LocalStore provideLocalStore() => InMemoryLocalStore();

  // P15 services
  @LazySingleton()
  ThreadBuilder provideThreadBuilder(LocalStore store) => ThreadBuilder(store);

  @LazySingleton()
  SpecialUseMapper provideSpecialUseMapper() => SpecialUseMapper();

  @LazySingleton()
  MimeDecoder provideMimeDecoder() => MimeDecoder();

  @LazySingleton()
  UidWindowSync provideUidWindowSync(ImapGateway gateway, LocalStore store) => UidWindowSync(gateway: gateway, store: store);

  @LazySingleton()
  FlagConflictResolver provideFlagConflictResolver() => FlagConflictResolver();

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

/// Legacy facade used when the kill switch is enabled. It intentionally does not implement behavior.
class LegacyMessageRepositoryFacade implements MessageRepository {
  const LegacyMessageRepositoryFacade();
  @override
  Future<List<Attachment>> listAttachments({required Folder folder, required String messageId}) async =>
      throw UnsupportedError('legacy facade');
  @override
  Future<Message> fetchMessageBody({required Folder folder, required String messageId}) async =>
      throw UnsupportedError('legacy facade');
  @override
  Future<List<Message>> fetchInbox({required Folder folder, int limit = 50, int offset = 0}) async =>
      throw UnsupportedError('legacy facade');
  @override
  Future<void> markRead({required Folder folder, required String messageId, required bool read}) async =>
      throw UnsupportedError('legacy facade');
  @override
  Future<List<int>> downloadAttachment({required Folder folder, required String messageId, required String partId}) async =>
      throw UnsupportedError('legacy facade');
  @override
  Future<List<SearchResult>> search({required String accountId, required SearchQuery q}) async =>
      throw UnsupportedError('legacy facade');
}

// Internal test override to avoid GetStorage in unit tests
bool? _killSwitchOverrideForTests;
void setKillSwitchOverrideForTests(bool? value) {
  _killSwitchOverrideForTests = value;
}

MessageRepository wireMessageRepository({required ImapGateway gateway, required LocalStore store, String? accountId}) {
  if (_killSwitchOverrideForTests == true) {
    return const LegacyMessageRepositoryFacade();
  }
  try {
    if (FeatureFlags.instance.dddKillSwitchEnabled) {
      return const LegacyMessageRepositoryFacade();
    }
  } catch (_) {
    // If FeatureFlags storage is not available, default to normal binding
  }
  final acc = accountId ?? ((GetStorage().read('email') as String?) ?? 'default-account');
  return ImapMessageRepository(accountId: acc, gateway: gateway, store: store);
}
