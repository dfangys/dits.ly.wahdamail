import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/observability/budget_parser.dart';

void main() {
  test('budget parser handles normalized and legacy fields', () {
    final lines = <String>[
      "[telemetry] fetch_body { op: 'fetch_body', ok: true, latency_ms: 120 }",
      "[telemetry] fetch_body { op: 'fetch_body', ok: true, lat_ms: 80 }",
      "[telemetry] search { op: 'search', ok: true, latency_ms: 50 }",
      "[telemetry] search { op: 'search', ok: false, latency_ms: 150 }",
      // legacy success/failure
      "[telemetry] search_success { ms: 10 }",
      "[telemetry] search_failure { ms: 20 }",
    ];

    final m = parseTelemetryLines(lines);

    // Success rate counts both ok flags and legacy markers
    expect(m.searchSuccess + m.searchFailure, 4);
    expect(m.searchSuccessRate() > 0 && m.searchSuccessRate() < 1, isTrue);

    // Latency percentiles compute over collected ops
    final p50Fetch = m.percentile('fetch_body', 50);
    final p95Fetch = m.percentile('fetch_body', 95);
    expect(p50Fetch, greaterThan(0));
    expect(p95Fetch, greaterThanOrEqualTo(p50Fetch));
  });
}

