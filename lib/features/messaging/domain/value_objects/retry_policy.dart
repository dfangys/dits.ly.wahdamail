/// Domain value object: Retry policy for send failures.
/// Backoff schedule example: 1m, 5m, 30m, 2h; capped at 24h.
class RetryPolicy {
  final List<Duration> schedule;
  final Duration maxBackoff;

  const RetryPolicy({
    this.schedule = const [
      Duration(minutes: 1),
      Duration(minutes: 5),
      Duration(minutes: 30),
      Duration(hours: 2),
    ],
    this.maxBackoff = const Duration(hours: 24),
  });

  DateTime nextRetryAt({required DateTime now, required int attemptCount}) {
    // attemptCount is the number of failures so far; next backoff is schedule[min(attemptCount, last)]
    Duration backoff;
    if (attemptCount < schedule.length) {
      backoff = schedule[attemptCount];
    } else {
      backoff = schedule.last;
    }
    if (backoff > maxBackoff) backoff = maxBackoff;
    return now.add(backoff);
  }
}

