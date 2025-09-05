import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/rendering/infrastructure/cid_resolver.dart';
import 'package:wahda_bank/features/messaging/infrastructure/dtos/attachment_row.dart';

void main() {
  test('CidResolver maps attachments with cid to InlineImageRef', () {
    final r = CidResolver();
    final rows = [
      AttachmentRow(
        messageUid: 'm1',
        partId: '1',
        filename: 'a.png',
        mimeType: 'image/png',
        sizeBytes: 123,
        contentId: 'abc@cid',
      ),
      AttachmentRow(
        messageUid: 'm1',
        partId: '2',
        filename: 'b.txt',
        mimeType: 'text/plain',
        sizeBytes: 10,
        contentId: null,
      ),
    ];
    final list = r.resolveFromAttachments(rows);
    expect(list.length, 1);
    expect(list.first.cid, 'abc@cid');
  });
}
