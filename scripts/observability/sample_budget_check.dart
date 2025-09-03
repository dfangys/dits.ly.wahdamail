// scripts/observability/sample_budget_check.dart
// Dev aid: parse telemetry lines from stdin or a file and compute simple rolling metrics.
// Usage: dart run scripts/observability/sample_budget_check.dart < logs.txt
// Expects lines like: "[telemetry] <name> { ... op: 'fetch_body', lat_ms: 123, ... }"

import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final latencies = <String, List<int>>{}; // op -> latencies
  int searchSuccess = 0;
  int searchFailure = 0;
  await stdin.transform(utf8.decoder).transform(const LineSplitter()).forEach((line) {
    if (!line.contains('[telemetry]')) return;
    // crude parse: try to extract name and props
    final nameMatch = RegExp(r"\[telemetry\]\s+(\w+)").firstMatch(line);
    final name = nameMatch?.group(1) ?? '';
    if (name == 'search_success') searchSuccess++;
    if (name == 'search_failure') searchFailure++;

    // find op and latency
    String op = 'unknown';
    int? lat;
    final opMatch = RegExp(r"op:\s*'?([A-Za-z0-9_]+)'").firstMatch(line);
    if (opMatch != null) {
      op = opMatch.group(1)!;
    } else {
      op = name;
    }
    final latMsMatch = RegExp(r"lat_ms:\s*(\d+)").firstMatch(line) ?? RegExp(r"ms:\s*(\d+)").firstMatch(line);
    if (latMsMatch != null) {
      lat = int.tryParse(latMsMatch.group(1)!);
    }
    if (lat != null) {
      latencies.putIfAbsent(op, () => <int>[]).add(lat);
      // bound memory
      if (latencies[op]!.length > 1000) {
        latencies[op]!.removeRange(0, 500);
      }
    }
  });

  double percentile(List<int> xs, int p) {
    if (xs.isEmpty) return 0;
    final copy = List<int>.from(xs)..sort();
    final idx = ((p / 100) * (copy.length - 1)).round();
    return copy[idx].toDouble();
  }

  double rate(int a, int b) => (a + b) == 0 ? 0.0 : a / (a + b);

  final opsOfInterest = ['inbox_open', 'fetch_body', 'search'];
  stdout.writeln('=== Budget Check (rolling) ===');
  stdout.writeln('search_success_rate: ${rate(searchSuccess, searchFailure).toStringAsFixed(3)}');
  for (final op in opsOfInterest) {
    final xs = latencies[op] ?? const <int>[];
    stdout.writeln('$op p50: ${percentile(xs, 50)} ms, p95: ${percentile(xs, 95)} ms');
  }
}

