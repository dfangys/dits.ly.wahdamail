import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/messaging/domain/value_objects/thread_key.dart';

void main() {
  test('ThreadKey: replies anchor to originals via RFC headers', () {
    final root = ThreadKey.fromHeaders(
      messageId: '<m1@x>',
      inReplyTo: null,
      references: const [],
      subject: 'Hello',
    );
    final reply = ThreadKey.fromHeaders(
      messageId: '<m2@x>',
      inReplyTo: '<m1@x>',
      references: const ['<m1@x>'],
      subject: 'Re: Hello',
    );
    expect(root, equals(reply));
  });

  test('ThreadKey: subject fallback normalizes prefixes', () {
    final a = ThreadKey.fromHeaders(
      messageId: null,
      inReplyTo: null,
      references: const [],
      subject: 'Re: Re: Hello',
    );
    final b = ThreadKey.fromHeaders(
      messageId: null,
      inReplyTo: null,
      references: const [],
      subject: 'Hello',
    );
    expect(a, equals(b));
  });

  test('ThreadKey: case/whitespace-insensitive', () {
    final a = ThreadKey.fromHeaders(
      messageId: null,
      inReplyTo: null,
      references: const [],
      subject: '  fWd:  Hello  ',
    );
    final b = ThreadKey.fromHeaders(
      messageId: null,
      inReplyTo: null,
      references: const [],
      subject: 'hello',
    );
    expect(a, equals(b));
  });
}
