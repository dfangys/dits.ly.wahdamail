/// Value Object: EmailAddress
/// Ensures a normalized, valid email address representation.
class EmailAddress {
  final String name; // display name; may be empty
  final String email; // normalized lowercase email

  EmailAddress(this.name, String email) : email = email.trim().toLowerCase() {
    if (!_isValidEmail(this.email)) {
      throw ArgumentError('Invalid email address: $email');
    }
  }

  static bool _isValidEmail(String s) {
    final at = s.indexOf('@');
    if (at <= 0 || at == s.length - 1) return false;
    if (s.contains(' ')) return false;
    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmailAddress && other.name == name && other.email == email;

  @override
  int get hashCode => Object.hash(name, email);
}
