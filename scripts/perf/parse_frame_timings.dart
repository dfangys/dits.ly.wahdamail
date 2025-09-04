// Dev-only: parse telemetry lines to compute p50 dropped frame percentage for mailbox/search scroll.
// Usage:
//   dart run scripts/perf/parse_frame_timings.dart <path-to-log>
// Or pipe logs:
//   flutter run -d <device> | dart run scripts/perf/parse_frame_timings.dart
import 'dart:convert';
import 'dart:io';

final _reTelemetry = RegExp(r"^\[telemetry\] operation \{(.+)\}");

double _p(List<double> xs, int p) {
  if (xs.isEmpty) return 0.0;
  final c = List<double>.from(xs)..sort();
  final i = ((p / 100) * (c.length - 1)).round();
  return c[i];
}

void main(List<String> args) async {
  final lines = <String>[];
  if (args.isNotEmpty) {
    final f = File(args.first);
    if (await f.exists()) {
      lines.addAll(await f.readAsLines());
    }
  }
  if (lines.isEmpty) {
    // Read stdin
    final input = await utf8.decoder.bind(stdin).toList();
    lines.addAll(input.join().split('\n'));
  }

  final droppedByOp = <String, List<double>>{};
  for (final line in lines) {
    final m = _reTelemetry.firstMatch(line.trim());
    if (m == null) continue;
    final body = m.group(1)!; // e.g. op: mailbox_list_scroll, dropped_pct: 3.2, ...
    if (!(body.contains('op: mailbox_list_scroll') || body.contains('op: search_list_scroll'))) continue;

    String op = 'unknown';
    double? dropped;

    // Simple key:value scanner over comma-separated pairs
    for (final part in body.split(',')) {
      final kv = part.trim().split(':');
      if (kv.length < 2) continue;
      final k = kv[0].trim();
      final v = kv.sublist(1).join(':').trim();
      if (k == 'op') op = v;
      if (k == 'dropped_pct') {
        dropped = double.tryParse(v);
      }
    }
    if (dropped != null) {
      droppedByOp.putIfAbsent(op, () => <double>[]).add(dropped!);
    }
  }

  for (final entry in droppedByOp.entries) {
    final p50 = _p(entry.value, 50).toStringAsFixed(2);
    final p95 = _p(entry.value, 95).toStringAsFixed(2);
    stdout.writeln('${entry.key}_dropped_pct_p50=$p50');
    stdout.writeln('${entry.key}_dropped_pct_p95=$p95');
  }

  // Budget hints
  stdout.writeln('\nBudgets (observe only):');
  stdout.writeln('  mailbox_list_scroll_dropped_pct_p50 <= 5%');
  stdout.writeln('  search_list_scroll_dropped_pct_p50 <= 5%');
}

