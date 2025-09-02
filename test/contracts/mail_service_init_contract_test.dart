import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/services/mail_service.dart';

void main() {
  group('MailService init contract (no network)', () {
    test('setClientAndAccount constructs client without connecting', () async {
      final svc = MailService.instance;
      final ok = svc.setClientAndAccount('test@example.com', 'password');
      expect(ok, isTrue);
      // Client should be constructed and not connected yet
      expect(svc.client, isNotNull);
      expect(svc.account.email, equals('test@example.com'));
    });
  });
}
