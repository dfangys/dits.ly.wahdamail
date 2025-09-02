import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/sync/infrastructure/jitter_backoff.dart';

void main() {
  test('JitterBackoff computes bounded delays', () {
    final backoff = JitterBackoff(baseSchedule: const [
      Duration(seconds: 10),
      Duration(seconds: 20),
    ], maxBackoff: const Duration(seconds: 30), jitter: 0.1);

    final d0 = backoff.forAttempt(0);
    expect(d0.inMilliseconds, inInclusiveRange(10000, 11000));

    final d1 = backoff.forAttempt(1);
    expect(d1.inMilliseconds, inInclusiveRange(20000, 22000));

    final d2 = backoff.forAttempt(2); // capped to last base value + jitter
    expect(d2.inMilliseconds, inInclusiveRange(20000, 22000));
  });
}

