// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;

import '../../features/enterprise_api/domain/repositories/accounts_repository.dart'
    as _i723;
import '../../features/enterprise_api/domain/repositories/contacts_repository.dart'
    as _i391;
import '../../features/enterprise_api/domain/repositories/signatures_repository.dart'
    as _i514;
import '../../features/enterprise_api/infrastructure/di/enterprise_api_module.dart'
    as _i449;
import '../../features/enterprise_api/infrastructure/gateways/rest_gateway.dart'
    as _i749;
import '../../features/enterprise_api/infrastructure/token_store.dart' as _i660;
import '../../features/messaging/domain/repositories/draft_repository.dart'
    as _i443;
import '../../features/messaging/domain/repositories/message_repository.dart'
    as _i898;
import '../../features/messaging/domain/repositories/outbox_repository.dart'
    as _i1018;
import '../../features/messaging/infrastructure/datasources/draft_dao.dart'
    as _i232;
import '../../features/messaging/infrastructure/datasources/local_store.dart'
    as _i802;
import '../../features/messaging/infrastructure/datasources/outbox_dao.dart'
    as _i543;
import '../../features/messaging/infrastructure/di/messaging_module.dart'
    as _i953;
import '../../features/messaging/infrastructure/facade/ddd_mail_service_impl.dart'
    as _i1039;
import '../../features/messaging/infrastructure/facade/legacy_messaging_facade.dart'
    as _i61;
import '../../features/messaging/infrastructure/gateways/imap_gateway.dart'
    as _i569;
import '../../features/messaging/infrastructure/gateways/smtp_gateway.dart'
    as _i1033;
import '../../features/messaging/presentation/compose_view_model.dart' as _i390;
import '../../features/messaging/presentation/mailbox_view_model.dart' as _i77;
import '../../features/notifications/domain/ports/notification_port.dart'
    as _i1015;
import '../../features/notifications/infrastructure/di/notifications_module.dart'
    as _i887;
import '../../features/notifications/infrastructure/notification_adapter.dart'
    as _i252;
import '../../features/rendering/domain/services/message_rendering_service.dart'
    as _i762;
import '../../features/rendering/infrastructure/cid_resolver.dart' as _i906;
import '../../features/rendering/infrastructure/di/rendering_module.dart'
    as _i479;
import '../../features/rendering/infrastructure/html_sanitizer.dart' as _i105;
import '../../features/rendering/infrastructure/preview_cache.dart' as _i992;
import '../../features/search/presentation/search_view_model.dart' as _i961;
import '../../features/security/domain/repositories/keyring_repository.dart'
    as _i1039;
import '../../features/security/domain/repositories/trust_repository.dart'
    as _i310;
import '../../features/security/domain/services/crypto_engine.dart' as _i983;
import '../../features/security/domain/services/encryption_service.dart'
    as _i887;
import '../../features/security/infrastructure/di/security_module.dart'
    as _i246;
import '../../features/settings/domain/settings_repository.dart' as _i915;
import '../../features/sync/application/event_bus.dart' as _i52;
import '../../features/sync/infrastructure/bg_fetch_ios.dart' as _i1062;
import '../../features/sync/infrastructure/circuit_breaker.dart' as _i450;
import '../../features/sync/infrastructure/connectivity_monitor.dart' as _i731;
import '../../features/sync/infrastructure/di/sync_module.dart' as _i958;
import '../../features/sync/infrastructure/sync_scheduler.dart' as _i505;
import '../../features/sync/infrastructure/sync_service.dart' as _i706;
import '../flags/cohort_service.dart' as _i71;
import '../flags/remote_flags.dart' as _i944;
import '../telemetry/tracing.dart' as _i704;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt init(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(
    getIt,
    environment,
    environmentFilter,
  );
  final syncModule = _$SyncModule();
  final messagingModule = _$MessagingModule();
  final enterpriseApiModule = _$EnterpriseApiModule();
  final securityModule = _$SecurityModule();
  final notificationsModule = _$NotificationsModule();
  final renderingModule = _$RenderingModule();
  gh.lazySingleton<_i52.SyncEventBus>(() => syncModule.provideSyncEventBus());
  gh.lazySingleton<_i450.CircuitBreaker>(
      () => syncModule.provideCircuitBreaker());
  gh.lazySingleton<_i802.LocalStore>(() => messagingModule.provideLocalStore());
  gh.lazySingleton<_i569.ImapGateway>(
      () => messagingModule.provideImapGateway());
  gh.lazySingleton<_i543.OutboxDao>(() => messagingModule.provideOutboxDao());
  gh.lazySingleton<_i232.DraftDao>(() => messagingModule.provideDraftDao());
  gh.lazySingleton<_i1033.SmtpGateway>(
      () => messagingModule.provideSmtpGateway());
  gh.lazySingleton<_i61.LegacyMessagingFacade>(
      () => _i61.LegacyMessagingFacade());
  gh.lazySingleton<_i749.MailsysApiClient>(
      () => enterpriseApiModule.provideApiClient());
  gh.lazySingleton<_i749.BackoffStrategy>(
      () => enterpriseApiModule.provideBackoff());
  gh.lazySingleton<_i660.TokenStore>(
      () => enterpriseApiModule.provideTokenStore());
  gh.lazySingleton<_i1039.KeyringRepository>(
      () => securityModule.provideKeyring());
  gh.lazySingleton<_i310.TrustRepository>(() => securityModule.provideTrust());
  gh.lazySingleton<_i983.CryptoEngine>(
      () => securityModule.provideCryptoEngine());
  gh.lazySingleton<_i1015.NotificationPort>(
      () => notificationsModule.provideNotificationPort());
  gh.lazySingleton<_i915.SettingsRepository>(
      () => notificationsModule.provideSettingsRepository());
  gh.lazySingleton<_i105.HtmlSanitizer>(
      () => renderingModule.provideSanitizer());
  gh.lazySingleton<_i906.CidResolver>(
      () => renderingModule.provideCidResolver());
  gh.lazySingleton<_i992.PreviewCache>(
      () => renderingModule.providePreviewCache());
  gh.lazySingleton<_i961.SearchViewModel>(() => _i961.SearchViewModel());
  gh.lazySingleton<_i77.MailboxViewModel>(() => _i77.MailboxViewModel());
  gh.lazySingleton<_i390.ComposeViewModel>(() => _i390.ComposeViewModel());
  gh.lazySingleton<_i944.RemoteFlags>(() => _i944.RemoteFlags());
  gh.lazySingleton<_i71.CohortService>(() => const _i71.CohortService());
  gh.lazySingleton<_i704.Tracing>(() => _i704.Tracing());
  gh.lazySingleton<_i1018.OutboxRepository>(
      () => messagingModule.provideOutboxRepository(gh<_i543.OutboxDao>()));
  gh.lazySingleton<_i898.MessageRepository>(
      () => messagingModule.provideMessageRepository(
            gh<_i569.ImapGateway>(),
            gh<_i802.LocalStore>(),
          ));
  gh.lazySingleton<_i749.RestGateway>(
      () => enterpriseApiModule.provideRestGateway(
            gh<_i749.MailsysApiClient>(),
            gh<_i749.BackoffStrategy>(),
          ));
  gh.lazySingleton<_i731.ConnectivityMonitor>(
      () => syncModule.provideConnectivityMonitor(
            gh<_i898.MessageRepository>(),
            gh<_i450.CircuitBreaker>(),
          ));
  gh.lazySingleton<_i1062.BgFetchIos>(() => syncModule.provideBgFetchIos(
        gh<_i898.MessageRepository>(),
        gh<_i450.CircuitBreaker>(),
        gh<_i52.SyncEventBus>(),
      ));
  gh.lazySingleton<_i443.DraftRepository>(
      () => messagingModule.provideDraftRepository(gh<_i232.DraftDao>()));
  gh.lazySingleton<_i1039.DddMailServiceImpl>(
      () => _i1039.DddMailServiceImpl(gh<_i898.MessageRepository>()));
  gh.lazySingleton<_i762.MessageRenderingService>(
      () => renderingModule.provideMessageRenderingService(
            gh<_i802.LocalStore>(),
            gh<_i105.HtmlSanitizer>(),
            gh<_i906.CidResolver>(),
            gh<_i992.PreviewCache>(),
          ));
  gh.lazySingleton<_i252.NotificationsCoordinator>(() =>
      notificationsModule.provideCoordinator(gh<_i1015.NotificationPort>()));
  gh.lazySingleton<_i723.AccountsRepository>(
      () => enterpriseApiModule.provideAccountsRepository(
            gh<_i749.RestGateway>(),
            gh<_i660.TokenStore>(),
          ));
  gh.lazySingleton<_i391.ContactsRepository>(
      () => enterpriseApiModule.provideContactsRepository(
            gh<_i749.RestGateway>(),
            gh<_i660.TokenStore>(),
          ));
  gh.lazySingleton<_i514.SignaturesRepository>(
      () => enterpriseApiModule.provideSignaturesRepository(
            gh<_i749.RestGateway>(),
            gh<_i660.TokenStore>(),
          ));
  gh.lazySingleton<_i887.EncryptionService>(
      () => securityModule.provideEncryptionService(
            gh<_i983.CryptoEngine>(),
            gh<_i1039.KeyringRepository>(),
          ));
  gh.lazySingleton<_i706.SyncService>(() => syncModule.provideSyncService(
        gh<_i569.ImapGateway>(),
        gh<_i898.MessageRepository>(),
      ));
  gh.lazySingleton<_i505.SyncScheduler>(
      () => syncModule.provideSyncScheduler(gh<_i706.SyncService>()));
  return getIt;
}

class _$SyncModule extends _i958.SyncModule {}

class _$MessagingModule extends _i953.MessagingModule {}

class _$EnterpriseApiModule extends _i449.EnterpriseApiModule {}

class _$SecurityModule extends _i246.SecurityModule {}

class _$NotificationsModule extends _i887.NotificationsModule {}

class _$RenderingModule extends _i479.RenderingModule {}
