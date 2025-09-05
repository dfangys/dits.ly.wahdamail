import 'package:wahda_bank/features/messaging/infrastructure/dtos/attachment_row.dart';
import 'package:wahda_bank/features/rendering/domain/value_objects/inline_image_ref.dart';

class CidResolver {
  List<InlineImageRef> resolveFromAttachments(List<AttachmentRow> rows) {
    final list = <InlineImageRef>[];
    for (final r in rows) {
      final cid = r.contentId;
      if (cid != null && cid.isNotEmpty) {
        list.add(
          InlineImageRef(
            cid: cid,
            contentType: r.mimeType,
            sizeBytes: r.sizeBytes,
          ),
        );
      }
    }
    return list;
  }
}
