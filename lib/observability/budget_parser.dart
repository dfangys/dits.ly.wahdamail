// lib/observability/budget_parser.dart
// Helper to parse telemetry lines and compute simple metrics (p50/p95 latencies, success rate).

class BudgetMetrics {
  final Map<String, List<int>> latenciesByOp;
  final int searchSuccess;
  final int searchFailure;
  BudgetMetrics({
    required this.latenciesByOp,
    required this.searchSuccess,
    required this.searchFailure,
  });

  double percentile(String op, int p) {
    final xs = latenciesByOp[op] ?? const <int>[];
    if (xs.isEmpty) return 0;
    final copy = List<int>.from(xs)..sort();
    final idx = ((p / 100) * (copy.length - 1)).round();
    return copy[idx].toDouble();
  }

  double searchSuccessRate() {
    final total = searchSuccess + searchFailure;
    if (total == 0) return 0.0;
    return searchSuccess / total;
  }
}

BudgetMetrics parseTelemetryLines(Iterable<String> lines) {
  final latencies = <String, List<int>>{}; // op -> latencies
  int searchSuccess = 0;
  int searchFailure = 0;

  for (final line in lines) {
    if (!line.contains('[telemetry]')) continue;
    // name from prefix
    final nameMatch = RegExp(r"\[telemetry\]\s+(\w+)").firstMatch(line);
    final name = nameMatch?.group(1) ?? '';

    // Back-compat explicit search success/failure markers
    if (name == 'search_success') searchSuccess++;
    if (name == 'search_failure') searchFailure++;

    // Extract normalized fields
    String op = 'unknown';
    int? lat;
    bool? ok;

    // op: prefer op: '<value>' in props; else fallback to name
    final opMatch = RegExp(r"op:\s*'?([A-Za-z0-9_]+)'").firstMatch(line);
    if (opMatch != null) {
      op = opMatch.group(1)!;
    } else {
      op = name;
    }

    // latency: prefer latency_ms, then lat_ms, then ms
    final latMatch =
        RegExp(r"latency_ms:\s*(\d+)").firstMatch(line) ??
        RegExp(r"lat_ms:\s*(\d+)").firstMatch(line) ??
        RegExp(r"ms:\s*(\d+)").firstMatch(line);
    if (latMatch != null) lat = int.tryParse(latMatch.group(1)!);

    // ok flag if present
    final okMatch = RegExp(r"ok:\s*(true|false)").firstMatch(line);
    if (okMatch != null) ok = okMatch.group(1) == 'true';

    // For search, also count by ok when op == 'search'
    if (op == 'search' && ok != null) {
      if (ok) {
        searchSuccess++;
      } else {
        searchFailure++;
      }
    }

    if (lat != null) {
      final bucket = latencies.putIfAbsent(op, () => <int>[]);
      bucket.add(lat);
      // bound memory
      if (bucket.length > 1000) {
        bucket.removeRange(0, 500);
      }
    }
  }

  return BudgetMetrics(
    latenciesByOp: latencies,
    searchSuccess: searchSuccess,
    searchFailure: searchFailure,
  );
}
