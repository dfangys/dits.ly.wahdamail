class SanitizationResult {
  final String html;
  final bool foundRemoteImages;
  const SanitizationResult(this.html, this.foundRemoteImages);
}

class HtmlSanitizer {
  SanitizationResult sanitize(String html, {bool allowRemote = false}) {
    var out = html;

    // Remove script and iframe tags
    out = out.replaceAll(RegExp(r'<\s*script[^>]*>[\s\S]*?<\s*/\s*script\s*>', caseSensitive: false), '');
    out = out.replaceAll(RegExp(r'<\s*iframe[^>]*>[\s\S]*?<\s*/\s*iframe\s*>', caseSensitive: false), '');

    // Remove inline event handlers like onload=, onclick=, etc.
    out = out.replaceAllMapped(RegExp(r'\s+on[a-zA-Z]+\s*=\s*(["\"][^"\"]*["\"]|[^\s>]+)', caseSensitive: false), (m) => '');

    // Remove external CSS links
    out = out.replaceAll(RegExp(r'<\s*link[^>]*rel\s*=\s*(["\"])stylesheet\1[^>]*>', caseSensitive: false), '');

    // Dangerous attributes: javascript: urls
    out = out.replaceAllMapped(RegExp(r'href\s*=\s*(["\"])javascript:[^\1]*\1', caseSensitive: false), (m) => '');

    // Handle remote <img src="http/https">
    bool foundRemote = false;
    out = out.replaceAllMapped(RegExp(r'<\s*img([^>]*?)src\s*=\s*(["\"])(http[s]?://[^"\"]+)\2([^>]*)>', caseSensitive: false), (m) {
      foundRemote = true;
      if (allowRemote) {
        return m.group(0)!; // keep
      } else {
        return '';
      }
    });

    return SanitizationResult(out, foundRemote && allowRemote);
  }
}
