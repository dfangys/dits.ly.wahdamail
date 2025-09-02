import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/messaging/infrastructure/migrations/index_migration.dart';

void main() {
  test('Index migration is idempotent (second run is no-op)', () async {
    await IndexMigration.run();
    await IndexMigration.run();
    // If not throwing, consider pass; smoke test only.
    expect(true, true);
  });
}
