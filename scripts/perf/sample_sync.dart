// Filters background/sync perf telemetry lines from flutter run output.
// Usage: flutter run -d <device> | dart run scripts/perf/sample_sync.dart
import 'dart:convert';
import 'dart:io';

void main(List<String> args) async {
  final ops = <String>{
    'idle_loop',
    'fetch_headers_batch',
    'bg_fetch_ios_cycle',
    'reconnect_window',
    'bg_fetch',
  };
  final input = stdin.transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in input) {
    final lower = line.toLowerCase();
    if (lower.contains('[telemetry]') && ops.any((op) => lower.contains(op))) {
      stdout.writeln(line);
    }
  }
}
