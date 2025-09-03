import '../value_objects/user_id.dart';

class AccountProfile {
  final UserId userId;
  final String email;
  final String displayName;

  const AccountProfile({
    required this.userId,
    required this.email,
    required this.displayName,
  });
}
