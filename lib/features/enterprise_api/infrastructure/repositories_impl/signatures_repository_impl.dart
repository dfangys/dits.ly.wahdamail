import '../../domain/entities/signature.dart' as dom;
import '../../domain/value_objects/user_id.dart';
import '../../domain/repositories/signatures_repository.dart';
import '../gateways/rest_gateway.dart';
import '../mappers/api_mappers.dart';
import '../token_store.dart';
import 'package:wahda_bank/shared/error/index.dart';
import 'accounts_repository_impl.dart';

class SignaturesRepositoryImpl implements SignaturesRepository {
  final RestGateway gateway;
  final TokenStore tokens;
  SignaturesRepositoryImpl({required this.gateway, required this.tokens});

  @override
  Future<dom.Signature> upsertSignature({
    required UserId userId,
    required dom.Signature signature,
  }) async {
    final t = tokens.read(userId);
    if (t == null) throw const AuthError('No token');
    try {
      final dto = await gateway.upsertSignature(
        userId: userId.value,
        accessToken: t.accessToken,
        dto: ApiMappers.fromDomainSignature(signature),
      );
      return ApiMappers.toDomainSignature(dto);
    } on AuthError {
      final fresh = await (AccountsRepositoryImpl(
        gateway: gateway,
        tokens: tokens,
      ).refreshToken(userId: userId));
      final dto = await gateway.upsertSignature(
        userId: userId.value,
        accessToken: fresh.accessToken,
        dto: ApiMappers.fromDomainSignature(signature),
      );
      return ApiMappers.toDomainSignature(dto);
    }
  }
}
