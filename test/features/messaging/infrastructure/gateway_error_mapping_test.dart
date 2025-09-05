import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';
import 'package:wahda_bank/shared/error/errors.dart';

void main() {
  group('IMAP gateway error mapping', () {
    test('maps auth errors', () {
      final e = Exception('Authentication failed');
      final ge = mapImapError(e);
      expect(ge, isA<AuthError>());
    });

    test('maps timeouts', () {
      final ge = mapImapError(Exception('Request timeout'));
      expect(ge, isA<TransientNetworkError>());
    });

    test('maps rate limit', () {
      final ge = mapImapError(
        Exception('Maximum number of connections from user+IP exceeded'),
      );
      expect(ge, isA<RateLimitError>());
    });

    test('maps default unknown to transient network', () {
      final ge = mapImapError(Exception('Some other error'));
      expect(ge, isA<TransientNetworkError>());
    });
  });
}
