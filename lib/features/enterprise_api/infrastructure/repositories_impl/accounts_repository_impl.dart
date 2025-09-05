import '../../domain/entities/account_profile.dart' as dom;
import '../../domain/value_objects/user_id.dart';
import '../../domain/value_objects/token.dart' as dom;
import '../../domain/repositories/accounts_repository.dart';
import '../gateways/rest_gateway.dart';
import '../mappers/api_mappers.dart';
import '../token_store.dart';
import 'package:wahda_bank/shared/error/index.dart';

class AccountsRepositoryImpl implements AccountsRepository {
  final RestGateway gateway;
  final TokenStore tokens;
  AccountsRepositoryImpl({required this.gateway, required this.tokens});

  @override
  Future<dom.AccountProfile> fetchAccountProfile({
    required UserId userId,
  }) async {
    final t = tokens.read(userId);
    if (t == null) throw const AuthError('No token');
    try {
      final dto = await gateway.fetchAccountProfile(
        userId: userId.value,
        accessToken: t.accessToken,
      );
      return ApiMappers.toDomainAccount(dto);
    } on AuthError {
      // Attempt refresh then retry once
      final fresh = await refreshToken(userId: userId);
      final dto = await gateway.fetchAccountProfile(
        userId: userId.value,
        accessToken: fresh.accessToken,
      );
      return ApiMappers.toDomainAccount(dto);
    }
  }

  @override
  Future<dom.Token> refreshToken({required UserId userId}) async {
    final t = tokens.read(userId);
    if (t == null) throw const AuthError('No refresh token');
    final ndto = await gateway.refreshToken(refreshToken: t.refreshToken);
    final nt = ApiMappers.toDomainToken(ndto);
    tokens.write(userId, nt);
    return nt;
  }
}
