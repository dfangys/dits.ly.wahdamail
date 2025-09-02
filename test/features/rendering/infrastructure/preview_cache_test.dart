import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/rendering/infrastructure/preview_cache.dart';
import 'package:wahda_bank/features/rendering/domain/services/message_rendering_service.dart';

void main() {
  test('PreviewCache stores/serves and evicts LRU', () {
    final c = PreviewCache(capacity: 2);
    final a = RenderedContent(sanitizedHtml: 'A', plainText: null, hasRemoteAssets: false, inlineImages: const []);
    final b = RenderedContent(sanitizedHtml: 'B', plainText: null, hasRemoteAssets: false, inlineImages: const []);
    final d = RenderedContent(sanitizedHtml: 'D', plainText: null, hasRemoteAssets: false, inlineImages: const []);

    c.put('a', a);
    c.put('b', b);
    expect(c.length, 2);

    // Access 'a' to make it recent
    expect(c.get('a')?.sanitizedHtml, 'A');

    // Insert 'd' -> evict LRU 'b'
    c.put('d', d);
    expect(c.get('b'), isNull);
    expect(c.get('a')?.sanitizedHtml, 'A');
    expect(c.get('d')?.sanitizedHtml, 'D');
  });
}
