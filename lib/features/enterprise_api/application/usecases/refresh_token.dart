import '../../domain/repositories/accounts_repository.dart';
import '../../domain/value_objects/token.dart';
import '../../domain/value_objects/user_id.dart';

class RefreshTokenUseCase {
  final AccountsRepository accounts;
  const RefreshTokenUseCase(this.accounts);

  Future<Token> call(UserId userId) => accounts.refreshToken(userId: userId);
}
