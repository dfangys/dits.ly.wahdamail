import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/models/sqlite_mime_storage.dart';
import 'package:wahda_bank/models/sqlite_database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('SQLiteMailboxMimeStorage.updateEnvelopeFromMessage', () {
    setUpAll(() {
      // Initialize FFI for sqflite in Dart VM tests
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });
    late MailAccount account;
    late Mailbox drafts;
    late SQLiteMailboxMimeStorage storage;

    setUp(() async {
      account = MailAccount.fromManualSettings(
        name: 'Tester',
        email: 'tester@example.com',
        incomingHost: 'localhost',
        outgoingHost: 'localhost',
        password: 'nopass',
        incomingType: ServerType.imap,
        outgoingType: ServerType.smtp,
      );
      drafts = Mailbox(
        encodedName: 'Drafts',
        encodedPath: 'Drafts',
        flags: [MailboxFlag.drafts],
        pathSeparator: '/',
      );
      drafts.name = 'Drafts';
      drafts.uidValidity = 7;

      storage = SQLiteMailboxMimeStorage(mailAccount: account, mailbox: drafts);
      await storage.init();
      // Ensure table is clean for this mailbox
      final db = await SQLiteDatabaseHelper.instance.database;
      final idRows = await db.query(SQLiteDatabaseHelper.tableMailboxes,
          columns: [SQLiteDatabaseHelper.columnId],
          where: '${SQLiteDatabaseHelper.columnName}=? AND ${SQLiteDatabaseHelper.columnAccountEmail}=?',
          whereArgs: [drafts.name, account.email]);
      if (idRows.isNotEmpty) {
        final mailboxId = idRows.first[SQLiteDatabaseHelper.columnId] as int;
        await db.delete(SQLiteDatabaseHelper.tableEmails,
            where: '${SQLiteDatabaseHelper.columnMailboxId}=?', whereArgs: [mailboxId]);
      }
    });

    test('writes subject and from for new row', () async {
      final m = MimeMessage();
      m.uid = 101;
      m.envelope = Envelope(
        date: DateTime.now(),
        subject: 'Hello',
        from: [const MailAddress('Alice', 'alice@example.com')],
        to: [const MailAddress('', 'bob@example.com')],
      );
      m.isSeen = true;

      await storage.updateEnvelopeFromMessage(m);
      final all = await storage.loadAllMessages();
      final found = all.firstWhere((x) => x.uid == 101, orElse: () => MimeMessage());
      expect((found.envelope?.subject ?? '').trim(), 'Hello');
      expect(found.envelope?.from?.first.email, 'alice@example.com');
      // Derived fields should exist in DB; envelope mapping hydrates sender
      // We assert sender_name is persisted indirectly by ensuring from exists
      expect(found.from?.first.email ?? found.envelope?.from?.first.email, isNotEmpty);
    });

    test('does not clobber non-empty subject/from with empty values', () async {
      // First, write non-empty values
      final m1 = MimeMessage()
        ..uid = 202
        ..envelope = Envelope(
          date: DateTime.now(),
          subject: 'KeepMe',
          from: [const MailAddress('Carol', 'carol@example.com')],
        );
      await storage.updateEnvelopeFromMessage(m1);

      // Then, attempt to update with empty subject and missing from
      final m2 = MimeMessage()
        ..uid = 202
        ..envelope = Envelope(
          date: DateTime.now(),
          subject: '',
          // no from provided
        );
      await storage.updateEnvelopeFromMessage(m2);

      final all = await storage.loadAllMessages();
      final found = all.firstWhere((x) => x.uid == 202);
      expect((found.envelope?.subject ?? '').trim(), 'KeepMe');
      expect(found.envelope?.from?.first.email, 'carol@example.com');
    });
  });
}

