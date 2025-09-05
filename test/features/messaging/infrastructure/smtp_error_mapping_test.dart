import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/smtp_gateway.dart';
import 'package:wahda_bank/shared/error/errors.dart';

void main() {
  group('SMTP gateway error mapping', () {
    test('auth errors', () {
      final e = mapSmtpError(Exception('Authentication failed'));
      expect(e, isA<AuthError>());
    });

    test('rate limit', () {
      final e = mapSmtpError(Exception('Too many requests'));
      expect(e, isA<RateLimitError>());
    });

    test('timeout', () {
      final e = mapSmtpError(Exception('Connection timeout'));
      expect(e, isA<TransientNetworkError>());
    });

    test('5xx permanent', () {
      final e = mapSmtpError(Exception('550 Requested action not taken'));
      expect(e, isA<PermanentProtocolError>());
    });
  });
}
