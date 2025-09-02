class EmailIdentity {
  final String email;
  final String? name;
  const EmailIdentity({required this.email, this.name});

  factory EmailIdentity.normalized(String email, {String? name}) =>
      EmailIdentity(email: email.trim().toLowerCase(), name: name?.trim());

  @override
  String toString() => name == null ? email : '$name <$email>';
  @override
  bool operator ==(Object other) => other is EmailIdentity && other.email == email;
  @override
  int get hashCode => email.hashCode;
}
