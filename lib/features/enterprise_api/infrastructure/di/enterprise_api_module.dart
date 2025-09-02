import 'package:injectable/injectable.dart';

import '../gateways/rest_gateway.dart';
import '../repositories_impl/accounts_repository_impl.dart';
import '../repositories_impl/contacts_repository_impl.dart';
import '../repositories_impl/signatures_repository_impl.dart';
import '../../domain/repositories/accounts_repository.dart';
import '../../domain/repositories/contacts_repository.dart';
import '../../domain/repositories/signatures_repository.dart';
import '../token_store.dart';

@module
abstract class EnterpriseApiModule {
  @LazySingleton()
  MailsysApiClient provideApiClient() => _NoopApiClient();

  @LazySingleton()
  BackoffStrategy provideBackoff() => const NoopBackoff();

  @LazySingleton()
  RestGateway provideRestGateway(MailsysApiClient client, BackoffStrategy backoff) => RestGateway(client, backoff: backoff);

  @LazySingleton()
  TokenStore provideTokenStore() => InMemoryTokenStore();

  @LazySingleton()
  AccountsRepository provideAccountsRepository(RestGateway gateway, TokenStore tokens) =>
      AccountsRepositoryImpl(gateway: gateway, tokens: tokens);

  @LazySingleton()
  ContactsRepository provideContactsRepository(RestGateway gateway, TokenStore tokens) =>
      ContactsRepositoryImpl(gateway: gateway, tokens: tokens);

  @LazySingleton()
  SignaturesRepository provideSignaturesRepository(RestGateway gateway, TokenStore tokens) =>
      SignaturesRepositoryImpl(gateway: gateway, tokens: tokens);
}

class _NoopApiClient implements MailsysApiClient {
  @override
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? headers, Map<String, String>? query}) async => {};

  @override
  Future<Map<String, dynamic>> post(String path, {Map<String, String>? headers, Object? body}) async => {};

  @override
  Future<Map<String, dynamic>> put(String path, {Map<String, String>? headers, Object? body}) async => {};
}
