import 'dart:async';
import 'dart:math';

/// Jittered backoff helper for reconnect/retry scheduling.
class JitterBackoff {
  final List<Duration> baseSchedule;
  final Duration maxBackoff;
  final double jitter; // 0.0..1.0 of base
  final Random _rng;

  JitterBackoff({
    this.baseSchedule = const [
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
      Duration(minutes: 1),
    ],
    this.maxBackoff = const Duration(minutes: 5),
    this.jitter = 0.2,
    Random? rng,
  }) : _rng = rng ?? Random();

  Duration forAttempt(int attempt) {
    final idx = attempt < baseSchedule.length ? attempt : baseSchedule.length - 1;
    var base = baseSchedule[idx];
    if (base > maxBackoff) base = maxBackoff;
    final jitterMillis = (base.inMilliseconds * jitter).round();
    final delta = _rng.nextInt(jitterMillis + 1); // 0..jitter
    return Duration(milliseconds: base.inMilliseconds + delta);
  }
}

