import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/messaging/infrastructure/special_use_mapper.dart';

void main() {
  test('Special-use mapping and tenant overrides', () {
    final mapper = SpecialUseMapper(tenantOverrides: {
      'Folder-123': SpecialUse.archive,
      'Sent Items': SpecialUse.sent,
    });

    expect(mapper.mapFor(folderId: 'INBOX', serverFlags: ['\\Inbox']), SpecialUse.inbox);
    expect(mapper.mapFor(folderId: 'Folder-123', serverFlags: ['\\Trash']), SpecialUse.archive); // override wins
    expect(mapper.mapFor(folderId: 'SENT', serverName: 'Sent Items', serverFlags: []), SpecialUse.sent);
  });
}

