import '../../domain/value_objects/token.dart';

class ValidateSession {
  const ValidateSession();
  bool call(Token token, {DateTime? now}) => token.isExpiredAt(now ?? DateTime.now()) == false;
}
