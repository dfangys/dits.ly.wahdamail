// Dev-only helper: filter compose perf telemetry from flutter run output.
// Usage:
//   flutter run -d <device> | dart run scripts/perf/sample_compose.dart | 
//   dart run scripts/perf/parse_frame_timings.dart
import 'dart:convert';
import 'dart:io';

void main() async {
  stdout.writeln('Sampling compose perf telemetry from stdin...');
  await for (final chunk in stdin.transform(utf8.decoder)) {
    for (final line in chunk.split('\n')) {
      final t = line.trim();
      if (t.startsWith('[telemetry] operation') &&
          (t.contains('op: compose_editor_interaction') || t.contains('op: compose_attachments_scroll'))) {
        stdout.writeln(t);
      }
    }
  }
}

