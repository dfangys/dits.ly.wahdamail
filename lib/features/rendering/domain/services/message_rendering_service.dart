import 'package:wahda_bank/features/messaging/domain/entities/message.dart';
import 'package:wahda_bank/features/rendering/domain/value_objects/inline_image_ref.dart';

class RenderedContent {
  final String sanitizedHtml;
  final String? plainText;
  final bool hasRemoteAssets;
  final List<InlineImageRef> inlineImages;
  const RenderedContent({
    required this.sanitizedHtml,
    this.plainText,
    required this.hasRemoteAssets,
    required this.inlineImages,
  });
}

abstract class MessageRenderingService {
  Future<RenderedContent> render(Message msg, {bool allowRemote = false});
}
