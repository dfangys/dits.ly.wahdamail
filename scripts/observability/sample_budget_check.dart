// scripts/observability/sample_budget_check.dart
// Dev aid: parse telemetry lines from stdin or a file and compute simple rolling metrics.
// Usage: dart run scripts/observability/sample_budget_check.dart < logs.txt
// Expects lines like: "[telemetry] <name> { ... op: 'fetch_body', latency_ms: 123, ... }"

import 'dart:convert';
import 'dart:io';

import 'package:wahda_bank/observability/budget_parser.dart';

void main(List<String> args) async {
  final lines = <String>[];
  await stdin
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .forEach(lines.add);
  final metrics = parseTelemetryLines(lines);

  final opsOfInterest = ['inbox_open', 'fetch_body', 'search'];
  stdout.writeln('=== Budget Check (rolling) ===');
  stdout.writeln(
    'search_success_rate: ${metrics.searchSuccessRate().toStringAsFixed(3)}',
  );
  for (final op in opsOfInterest) {
    final p50 = metrics.percentile(op, 50);
    final p95 = metrics.percentile(op, 95);
    stdout.writeln('$op p50: $p50 ms, p95: $p95 ms');
  }
}
