import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';
import 'package:wahda_bank/features/messaging/infrastructure/mappers/message_mapper.dart';

void main() {
  test('MessageMapper maps HeaderDTO <-> MessageRow <-> domain', () {
    final h = HeaderDTO(
      id: '1',
      folderId: 'INBOX',
      subject: 'Hi',
      fromName: 'Alice',
      fromEmail: 'alice@example.com',
      toEmails: const ['bob@example.com'],
      dateEpochMs: 1000,
      seen: true,
      answered: false,
      flagged: false,
      draft: false,
      deleted: false,
      hasAttachments: false,
      preview: 'hi',
    );
    final row = MessageMapper.fromHeaderDTO(h);
    expect(row.subject, 'Hi');
    final d = MessageMapper.toDomain(row);
    expect(d.subject, 'Hi');
    expect(d.from.email, 'alice@example.com');
  });
}

