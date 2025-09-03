import 'package:wahda_bank/shared/error/errors.dart';
import 'package:wahda_bank/shared/utils/hashing.dart';
import 'package:wahda_bank/shared/telemetry/tracing.dart';

abstract class SmtpGateway {
  /// Send raw RFC822 bytes. Returns Message-Id if available.
  Future<String?> send({required String accountId, required List<int> rawBytes});
}

/// Map SMTP errors to taxonomy.
AppError mapSmtpError(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('auth') || s.contains('authentication')) return AuthError(e.toString(), e);
  if (s.contains('timeout') || s.contains('temporarily')) return TransientNetworkError(e.toString(), e);
  if (s.contains('rate') || s.contains('too many')) return RateLimitError(e.toString(), e);
  // Assume other 5xx as permanent protocol
  if (s.contains('5')) return PermanentProtocolError(e.toString(), e);
  return TransientNetworkError(e.toString(), e);
}

class EnoughSmtpGateway implements SmtpGateway {
  @override
  Future<String?> send({required String accountId, required List<int> rawBytes}) async {
    final span = Tracing.startSpan('SendSmtp', attrs: {'accountId_hash': Hashing.djb2(accountId).toString()});
    try {
      // P4 scope: infra-only; real SMTP handled in later phase or via SDK integration.
      // Here we simulate a success and return a synthetic Message-Id.
      return '<sent-${DateTime.now().millisecondsSinceEpoch}@wahda.local>';
    } finally {
      Tracing.end(span);
    }
  }
}
