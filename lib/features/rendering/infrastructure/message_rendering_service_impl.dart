import 'package:wahda_bank/features/messaging/domain/entities/message.dart' as dom;
import 'package:wahda_bank/features/messaging/infrastructure/datasources/local_store.dart';
import 'package:wahda_bank/features/rendering/domain/services/message_rendering_service.dart';
import 'package:wahda_bank/features/rendering/domain/value_objects/inline_image_ref.dart';
import 'package:wahda_bank/features/rendering/infrastructure/html_sanitizer.dart';
import 'package:wahda_bank/features/rendering/infrastructure/cid_resolver.dart';
import 'package:wahda_bank/features/rendering/infrastructure/preview_cache.dart';

class MessageRenderingServiceImpl implements MessageRenderingService {
  final LocalStore store;
  final HtmlSanitizer sanitizer;
  final CidResolver resolver;
  final PreviewCache cache;

  MessageRenderingServiceImpl({required this.store, required this.sanitizer, required this.resolver, required this.cache});

  @override
  Future<RenderedContent> render(dom.Message msg, {bool allowRemote = false}) async {
    final cacheKey = msg.id;
    final cached = cache.get(cacheKey);
    if (cached != null) return cached;

    final body = await store.getBody(messageUid: msg.id);
    if (body == null) {
      final empty = RenderedContent(sanitizedHtml: '', plainText: null, hasRemoteAssets: false, inlineImages: const <InlineImageRef>[]);
      cache.put(cacheKey, empty);
      return empty;
    }

    final html = body.html ?? '';
    final plain = body.plainText;
    final sanitized = sanitizer.sanitize(html, allowRemote: allowRemote);

    final atts = await store.listAttachments(messageUid: msg.id);
    final inline = resolver.resolveFromAttachments(atts);

    final rendered = RenderedContent(
      sanitizedHtml: sanitized.html,
      plainText: plain,
      hasRemoteAssets: sanitized.foundRemoteImages,
      inlineImages: inline,
    );
    cache.put(cacheKey, rendered);
    return rendered;
  }
}
