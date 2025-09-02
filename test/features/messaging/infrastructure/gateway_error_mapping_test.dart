import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';

void main() {
  group('IMAP gateway error mapping', () {
    test('maps auth errors', () {
      final e = Exception('Authentication failed');
      final ge = mapImapError(e);
      expect(ge.code, 'auth_error');
    });

    test('maps timeouts', () {
      final ge = mapImapError(Exception('Request timeout'));
      expect(ge.code, 'timeout');
    });

    test('maps rate limit', () {
      final ge = mapImapError(Exception('Maximum number of connections from user+IP exceeded'));
      expect(ge.code, 'rate_limited');
    });

    test('maps network default', () {
      final ge = mapImapError(Exception('Some other error'));
      expect(ge.code, 'network_error');
    });
  });
}

