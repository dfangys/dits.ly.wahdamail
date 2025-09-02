/// Centralized API configuration.
///
/// Values are provided via --dart-define at runtime. For example:
/// flutter run \
///   --dart-define=MAILSYS_BASE_URL=https://chase.com.ly \
///   --dart-define=MAILSYS_APP_TOKEN={{MAILSYS_APP_TOKEN}}
class ApiConfig {
  /// Base URL for the MailSys API (e.g., https://chase.com.ly)
  static const String baseUrl = String.fromEnvironment(
    'MAILSYS_BASE_URL',
    defaultValue: 'https://chase.com.ly',
  );

  /// App-level bearer token used for pre-auth endpoints (/api/login, /api/verify-otp).
  /// This must be provided at runtime; do not hardcode secrets.
  static const String appToken = String.fromEnvironment(
    'MAILSYS_APP_TOKEN',
    defaultValue: '',
  );
}
