import '../../domain/entities/contact.dart' as dom;
import '../../domain/value_objects/user_id.dart';
import '../../domain/repositories/contacts_repository.dart';
import '../gateways/rest_gateway.dart';
import '../mappers/api_mappers.dart';
import '../token_store.dart';
import 'package:wahda_bank/shared/error/index.dart';
import 'accounts_repository_impl.dart';

class ContactsRepositoryImpl implements ContactsRepository {
  final RestGateway gateway;
  final TokenStore tokens;
  ContactsRepositoryImpl({required this.gateway, required this.tokens});

  @override
  Future<List<dom.Contact>> listContacts({required UserId userId, int? limit, int? offset}) async {
    final t = tokens.read(userId);
    if (t == null) throw const AuthError('No token');
    try {
      final dtos = await gateway.listContacts(userId: userId.value, accessToken: t.accessToken, limit: limit, offset: offset);
      return dtos.map<dom.Contact>(ApiMappers.toDomainContact).toList(growable: false);
    } on AuthError {
      final fresh = await (AccountsRepositoryImpl(gateway: gateway, tokens: tokens).refreshToken(userId: userId));
      final dtos = await gateway.listContacts(userId: userId.value, accessToken: fresh.accessToken, limit: limit, offset: offset);
      return dtos.map<dom.Contact>(ApiMappers.toDomainContact).toList(growable: false);
    }
  }
}
