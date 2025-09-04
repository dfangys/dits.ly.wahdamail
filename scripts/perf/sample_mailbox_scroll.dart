// Dev-only helper: filter list-scroll telemetry lines from flutter run output.
// Usage:
//   flutter run -d <device> | dart run scripts/perf/sample_mailbox_scroll.dart
// Pipe the output to the parser for budgets:
//   flutter run -d <device> | dart run scripts/perf/sample_mailbox_scroll.dart | \
//   dart run scripts/perf/parse_frame_timings.dart
import 'dart:convert';
import 'dart:io';

void main() async {
  stdout.writeln('Sampling list scroll telemetry from stdin...');
  await for (final chunk in stdin.transform(utf8.decoder)) {
    for (final line in chunk.split('\n')) {
      final t = line.trim();
      if (t.startsWith('[telemetry] operation') && (t.contains('op: mailbox_list_scroll') || t.contains('op: search_list_scroll'))) {
        stdout.writeln(t);
      }
    }
  }
}

