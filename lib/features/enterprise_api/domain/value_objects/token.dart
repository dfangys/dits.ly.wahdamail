class Token {
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  const Token({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);
  bool get isExpired => isExpiredAt(DateTime.now());

  Token copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) => Token(
    accessToken: accessToken ?? this.accessToken,
    refreshToken: refreshToken ?? this.refreshToken,
    expiresAt: expiresAt ?? this.expiresAt,
  );
}
