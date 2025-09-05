import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/messaging/infrastructure/mime/mime_decoder.dart';

void main() {
  test('MIME decoding qp/base64 and charset handling', () {
    final d = MimeDecoder();

    // UTF-8 plain
    final utf8Text = d.decodeText(
      bytes: utf8.encode('Hello €'),
      charset: 'utf-8',
    );
    expect(utf8Text, 'Hello €');

    // quoted-printable for 'Hello=0A' (LF)
    final qp = d.decodeText(
      bytes: 'Hello=0AWorld'.codeUnits,
      transferEncoding: 'quoted-printable',
      charset: 'utf-8',
    );
    expect(qp, 'Hello\nWorld');

    // base64 for 'Hi' in utf-8
    final b64 = d.decodeText(
      bytes: utf8.encode('SGk='),
      transferEncoding: 'base64',
      charset: 'utf-8',
    );
    expect(b64, 'Hi');

    // windows-1252 smart quotes
    final cp1252 = d.decodeText(
      bytes: [0x93, 0x48, 0x69, 0x94],
      charset: 'windows-1252',
    );
    expect(cp1252, '“Hi”');
  });
}
