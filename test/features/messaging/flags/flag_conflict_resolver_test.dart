import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/messaging/infrastructure/flags/flag_conflict_resolver.dart';

void main() {
  test('Flag conflict resolution: last-writer-wins with server authority; retry on conflict', () {
    final r = FlagConflictResolver();

    final server = {'seen': false, 'flagged': false, 'answered': false};
    final localDesired = {'seen': true, 'flagged': true};

    final merged = r.resolve(localDesired: localDesired, serverFlags: server);
    expect(merged['seen'], true);
    expect(merged['flagged'], true);

    // Simulate STORE conflict: server still says seen=false
    final onConflict = r.onStoreConflict(serverFlags: server);
    expect(onConflict['seen'], false);
  });
}

