import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/messaging/domain/entities/message.dart' as ent;
import 'package:wahda_bank/features/messaging/domain/entities/folder.dart';

void main() {
  group('Message entity', () {
    test('copyWith and equality', () {
      final from = ent.EmailAddress('Alice', 'alice@example.com');
      final to = [ent.EmailAddress('Bob', 'bob@example.com')];
      final msg = ent.Message(
        id: 'm1',
        folderId: 'INBOX',
        subject: 'Hello',
        from: from,
        to: to,
        date: DateTime.fromMillisecondsSinceEpoch(0),
        flags: const ent.Flags(seen: false),
      );
      final msg2 = msg.copyWith(subject: 'Hello');
      expect(msg, equals(msg2));
      final msg3 = msg.copyWith(subject: 'Hi');
      expect(msg3 == msg, isFalse);
    });
  });

  group('Folder entity', () {
    test('value equality', () {
      const f1 = Folder(id: 'INBOX', name: 'Inbox', isInbox: true);
      const f2 = Folder(id: 'INBOX', name: 'Inbox', isInbox: true);
      expect(f1, equals(f2));
    });
  });
}

