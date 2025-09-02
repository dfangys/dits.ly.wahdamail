import '../entities/account_profile.dart';
import '../value_objects/user_id.dart';
import '../value_objects/token.dart';

abstract class AccountsRepository {
  Future<AccountProfile> fetchAccountProfile({required UserId userId});
  Future<Token> refreshToken({required UserId userId});
}
