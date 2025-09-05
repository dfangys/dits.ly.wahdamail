import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/sync/infrastructure/circuit_breaker.dart';

void main() {
  test('Circuit breaker transitions open -> half-open -> closed', () async {
    final cb = CircuitBreaker(
      failureThreshold: 2,
      openBase: const Duration(milliseconds: 200),
      jitter: 0.0,
    );

    // Initially closed
    expect(cb.allowExecution(), true);

    // Record failures to open the circuit
    cb.recordFailure();
    cb.recordFailure();
    expect(cb.allowExecution(), false); // open

    // Wait for reopen window
    await Future.delayed(const Duration(milliseconds: 210));

    // Now half-open: allow one trial
    expect(cb.allowExecution(), true);

    // If success, it should close
    cb.recordSuccess();
    expect(cb.allowExecution(), true);

    // Fail again: should open after threshold
    cb.recordFailure();
    cb.recordFailure();
    expect(cb.allowExecution(), false);
  });
}
