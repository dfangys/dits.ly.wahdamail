import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/messaging/infrastructure/dtos/body_row.dart';
import 'package:wahda_bank/features/messaging/infrastructure/dtos/attachment_row.dart';
import 'package:wahda_bank/features/messaging/infrastructure/gateways/imap_gateway.dart';
import 'package:wahda_bank/features/messaging/infrastructure/mappers/message_mapper.dart';
import 'package:wahda_bank/features/messaging/domain/entities/body.dart' as dom;
import 'package:wahda_bank/features/messaging/domain/entities/attachment.dart'
    as dom;

void main() {
  test('BodyDTO ⇄ BodyRow ⇄ domain BodyContent', () {
    final dto = BodyDTO(
      messageUid: '42',
      mimeType: 'text/html',
      plainText: null,
      html: '<b>hi</b>',
      sizeBytesEstimate: 10,
    );
    final row = MessageMapper.bodyRowFromDTO(dto);
    expect(row.messageUid, '42');
    final d = MessageMapper.bodyDomainFromRow(row);
    expect(d.mimeType, 'text/html');
    expect(d.html, '<b>hi</b>');
  });

  test('AttachmentDTO ⇄ AttachmentRow ⇄ domain Attachment', () {
    final dto = AttachmentDTO(
      messageUid: '42',
      partId: '1',
      filename: 'a.bin',
      mimeType: 'application/octet-stream',
      sizeBytes: 7,
      contentId: 'cid',
    );
    final row = MessageMapper.attachmentRowFromDTO(dto);
    expect(row.partId, '1');
    final d = MessageMapper.attachmentDomainFromRow(row);
    expect(d.partId, '1');
    expect(d.filename, 'a.bin');
  });
}
