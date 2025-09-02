import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';
import 'package:wahda_bank/shared/error/errors.dart';

void main() {
  group('IMAP gateway error mapping (body/attachments)', () {
    test('body fetch maps auth errors', () {
      final ge = mapImapError(Exception('Authentication failed'));
      expect(ge, isA<AuthError>());
    });

    test('attachment list maps rate limit', () {
      final ge = mapImapError(Exception('Maximum number of connections from user+IP exceeded'));
      expect(ge, isA<RateLimitError>());
    });

    test('attachment download maps transient timeout', () {
      final ge = mapImapError(Exception('Read timeout while fetching part'));
      expect(ge, isA<TransientNetworkError>());
    });
  });
}

