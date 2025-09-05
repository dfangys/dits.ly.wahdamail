import 'dart:math';

/// Simple circuit breaker with half-open trial and jittered reopen windows.
class CircuitBreaker {
  final int failureThreshold;
  final Duration openBase;
  final double jitter; // 0..1 of base
  final Random _rng;

  int _failures = 0;
  DateTime? _openUntil;
  bool _halfOpenTrialUsed = false;

  CircuitBreaker({
    this.failureThreshold = 3,
    this.openBase = const Duration(seconds: 15),
    this.jitter = 0.2,
    Random? rng,
  }) : _rng = rng ?? Random();

  bool get isOpen {
    if (_openUntil == null) return false;
    if (DateTime.now().isAfter(_openUntil!)) {
      // Move to half-open
      _openUntil = null;
      _halfOpenTrialUsed = false;
      return false;
    }
    return true;
  }

  bool allowExecution() {
    if (isOpen) return false;
    if (_halfOpenTrialUsed)
      return true; // After first trial, closed path handles
    // When transitioning to half-open, allow exactly one trial.
    if (_failures >= failureThreshold) {
      if (!_halfOpenTrialUsed) {
        _halfOpenTrialUsed = true;
        return true;
      }
    }
    return true;
  }

  void recordSuccess() {
    _failures = 0;
    _openUntil = null;
    _halfOpenTrialUsed = false;
  }

  void recordFailure() {
    _failures += 1;
    if (_failures >= failureThreshold) {
      final jitterMs = (openBase.inMilliseconds * jitter).round();
      final delta = _rng.nextInt(jitterMs + 1);
      _openUntil = DateTime.now().add(
        Duration(milliseconds: openBase.inMilliseconds + delta),
      );
      _halfOpenTrialUsed = false;
    }
  }
}
