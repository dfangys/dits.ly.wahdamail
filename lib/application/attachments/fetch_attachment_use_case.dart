import 'dart:typed_data';
import '../../domain/entities/attachment.dart';
import '../../domain/repositories/attachments_repository.dart';

class FetchAttachmentUseCase {
  final IAttachmentsRepository attachmentsRepository;
  const FetchAttachmentUseCase(this.attachmentsRepository);

  Future<Uint8List?> call(Attachment attachment) async {
    return attachmentsRepository.fetchAttachmentBytes(attachment);
  }
}
