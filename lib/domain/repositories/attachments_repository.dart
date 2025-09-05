import 'dart:typed_data';
import '../entities/attachment.dart';

abstract class IAttachmentsRepository {
  Future<Uint8List?> fetchAttachmentBytes(
    Attachment attachment, {
    Duration timeout = const Duration(seconds: 15),
  });
}
