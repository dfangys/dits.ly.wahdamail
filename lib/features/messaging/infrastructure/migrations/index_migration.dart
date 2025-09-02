import 'package:wahda_bank/shared/logging/telemetry.dart';

class IndexMigration {
  static bool _ran = false;

  static Future<void> run() async {
    if (_ran) {
      Telemetry.event('migration', props: {'name': 'indexes', 'op': 'noop'});
      return;
    }
    await Telemetry.timeAsync('migration_indexes', () async {
      // In-memory store: no-op. In real DB: create indices if not exist.
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }, props: {
      'op': 'create_if_missing',
      'indices': 'date_desc,(from,subject),(flags,date)'
    });
    _ran = true;
  }
}
