import '../domain/value_objects/token.dart';
import '../domain/value_objects/user_id.dart';

abstract class TokenStore {
  Token? read(UserId userId);
  void write(UserId userId, Token token);
}

class InMemoryTokenStore implements TokenStore {
  final Map<String, Token> _map = {};
  @override
  Token? read(UserId userId) => _map[userId.value];
  @override
  void write(UserId userId, Token token) => _map[userId.value] = token;
}
