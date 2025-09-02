import 'package:flutter_test/flutter_test.dart';
import 'package:wahda_bank/features/rendering/infrastructure/html_sanitizer.dart';

void main() {
  test('Sanitizer removes script/iframe/on* and blocks remote images by default', () {
    final s = HtmlSanitizer();
    final html = '<div onload="alert(1)"><script>alert(1)</script><iframe src="x"></iframe><img src="http://t"/><a href="javascript:evil()">x</a></div>';
    final res = s.sanitize(html);
    expect(res.html.contains('script'), false);
    expect(res.html.contains('iframe'), false);
    expect(res.html.contains('onload'), false);
    expect(res.html.contains('img'), false);
  });

  test('Sanitizer allows remote images when allowRemote=true and flags hasRemoteAssets', () {
    final s = HtmlSanitizer();
    final html = '<img src="https://example.com/i.png">';
    final res = s.sanitize(html, allowRemote: true);
    expect(res.html.contains('img'), true);
    expect(res.foundRemoteImages, true);
  });
  test('Sanitizer strips data: images, srcset, style url() and formaction', () {
    final s = HtmlSanitizer();
    final html = '<img src="data:image/png;base64,AAAA" srcset="http://a 1x" style="background:url(http://x)" formaction="http://evil">';
    final res = s.sanitize(html, allowRemote: true);
    expect(res.html.contains('data:'), false);
    expect(res.html.contains('srcset'), false);
    expect(res.html.contains('formaction'), false);
    expect(res.html.contains('url('), false);
  });
}
