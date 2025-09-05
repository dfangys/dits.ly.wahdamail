import 'dart:convert';

import 'package:wahda_bank/shared/logging/telemetry.dart';

/// MIME decoder: decoding of transfer-encodings and common charsets.
class MimeDecoder {
  String decodeText({
    required List<int> bytes,
    String? charset,
    String? transferEncoding,
    String? requestId,
  }) {
    final sw = Stopwatch()..start();
    List<int> payload = bytes;
    try {
      final enc = (transferEncoding ?? '').toLowerCase();
      if (enc == 'base64') {
        payload = base64.decode(utf8.decode(bytes));
      } else if (enc == 'quoted-printable') {
        payload = _decodeQuotedPrintable(bytes);
      }
      final cs = (charset ?? 'utf-8').toLowerCase();
      final text = _decodeCharset(payload, cs);
      Telemetry.event(
        'operation',
        props: {
          'op': 'MimeDecode',
          'lat_ms': sw.elapsedMilliseconds,
          if (requestId != null) 'request_id': requestId,
        },
      );
      return text;
    } catch (e) {
      Telemetry.event(
        'operation',
        props: {
          'op': 'MimeDecode',
          'lat_ms': sw.elapsedMilliseconds,
          'error_class': e.runtimeType.toString(),
        },
      );
      // Fallback best-effort
      return utf8.decode(payload, allowMalformed: true);
    }
  }

  List<int> _decodeQuotedPrintable(List<int> input) {
    // Simple QP decoder
    final out = <int>[];
    for (int i = 0; i < input.length; i++) {
      final c = input[i];
      if (c == 61 /* '=' */ ) {
        // soft line break
        if (i + 2 < input.length) {
          final h1 = input[i + 1];
          final h2 = input[i + 2];
          if (h1 == 13 && h2 == 10) {
            i += 2;
            continue;
          }
          final hex = String.fromCharCode(h1) + String.fromCharCode(h2);
          final val = int.tryParse(hex, radix: 16);
          if (val != null) {
            out.add(val);
            i += 2;
            continue;
          }
        }
        // malformed; keep '='
        out.add(c);
      } else {
        out.add(c);
      }
    }
    return out;
  }

  String _decodeCharset(List<int> bytes, String cs) {
    switch (cs) {
      case 'utf-8':
      case 'utf8':
        return utf8.decode(bytes, allowMalformed: true);
      case 'iso-8859-1':
      case 'latin1':
        return latin1.decode(bytes);
      case 'windows-1252':
        return _decodeCp1252(bytes);
      case 'windows-1256':
        // Approximate via utf8 fallback; proper mapping would require a table; allow malformed
        return utf8.decode(bytes, allowMalformed: true);
      default:
        return utf8.decode(bytes, allowMalformed: true);
    }
  }

  String _decodeCp1252(List<int> bytes) {
    // Map common cp1252 characters; fallback to latin1 for the rest
    final b =
        bytes.map((e) {
          switch (e) {
            case 0x80:
              return 0x20AC; // €
            case 0x82:
              return 0x201A;
            case 0x83:
              return 0x0192;
            case 0x84:
              return 0x201E;
            case 0x85:
              return 0x2026;
            case 0x86:
              return 0x2020;
            case 0x87:
              return 0x2021;
            case 0x88:
              return 0x02C6;
            case 0x89:
              return 0x2030;
            case 0x8A:
              return 0x0160;
            case 0x8B:
              return 0x2039;
            case 0x8C:
              return 0x0152;
            case 0x91:
              return 0x2018;
            case 0x92:
              return 0x2019;
            case 0x93:
              return 0x201C;
            case 0x94:
              return 0x201D;
            case 0x95:
              return 0x2022;
            case 0x96:
              return 0x2013;
            case 0x97:
              return 0x2014;
            case 0x98:
              return 0x02DC;
            case 0x99:
              return 0x2122;
            case 0x9A:
              return 0x0161;
            case 0x9B:
              return 0x203A;
            case 0x9C:
              return 0x0153;
            case 0x9F:
              return 0x0178;
            default:
              return e;
          }
        }).toList();
    // Encode codepoints to string
    return String.fromCharCodes(b);
  }
}
