import '../../domain/repositories/accounts_repository.dart';
import '../../domain/entities/account_profile.dart';
import '../../domain/value_objects/user_id.dart';

class FetchAccountProfile {
  final AccountsRepository accounts;
  const FetchAccountProfile(this.accounts);

  Future<AccountProfile> call(UserId userId) =>
      accounts.fetchAccountProfile(userId: userId);
}
