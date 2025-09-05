import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/messaging/domain/value_objects/retry_policy.dart';

void main() {
  test('RetryPolicy schedule matches 1m,5m,30m,2h capped at 24h', () {
    const policy = RetryPolicy();
    final now = DateTime(2024, 1, 1);
    expect(
      policy.nextRetryAt(now: now, attemptCount: 0).difference(now).inMinutes,
      1,
    );
    expect(
      policy.nextRetryAt(now: now, attemptCount: 1).difference(now).inMinutes,
      5,
    );
    expect(
      policy.nextRetryAt(now: now, attemptCount: 2).difference(now).inMinutes,
      30,
    );
    expect(
      policy.nextRetryAt(now: now, attemptCount: 3).difference(now).inHours,
      2,
    );
    // Beyond last, should cap at last (<=24h)
    expect(
      policy.nextRetryAt(now: now, attemptCount: 10).difference(now).inHours,
      2,
    );
  });
}
