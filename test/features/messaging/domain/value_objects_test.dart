import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/messaging/domain/value_objects/email_address.dart';
import 'package:wahda_bank/features/messaging/domain/value_objects/flags.dart';

void main() {
  group('EmailAddress', () {
    test('normalizes to lowercase and validates simple format', () {
      final e = EmailAddress('Alice', 'Alice@Example.com');
      expect(e.email, 'alice@example.com');
    });

    test('throws on invalid email', () {
      expect(() => EmailAddress('', 'not-an-email'), throwsArgumentError);
      expect(() => EmailAddress('', 'x@'), throwsArgumentError);
      expect(() => EmailAddress('', '@y'), throwsArgumentError);
    });

    test('equality on name+email', () {
      final a = EmailAddress('A', 'a@example.com');
      final b = EmailAddress('A', 'a@example.com');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('Flags', () {
    test('copyWith preserves immutability', () {
      const f = Flags(seen: true, flagged: true);
      final f2 = f.copyWith(answered: true);
      expect(f.seen, true);
      expect(f.flagged, true);
      expect(f.answered, false);
      expect(f2.answered, true);
      expect(f2.seen, true);
    });

    test('value equality', () {
      const f1 = Flags(seen: true);
      const f2 = Flags(seen: true);
      expect(f1, equals(f2));
      expect(f1.hashCode, equals(f2.hashCode));
    });
  });
}
