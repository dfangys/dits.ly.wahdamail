class SanitizationResult {
  final String html;
  final bool foundRemoteImages;
  const SanitizationResult(this.html, this.foundRemoteImages);
}

class HtmlSanitizer {
  SanitizationResult sanitize(String html, {bool allowRemote = false}) {
    var out = html;

    // Remove script and iframe tags
    out = out.replaceAll(
      RegExp(
        r'<\s*script[^>]*>[\s\S]*?<\s*/\s*script\s*>',
        caseSensitive: false,
      ),
      '',
    );
    out = out.replaceAll(
      RegExp(
        r'<\s*iframe[^>]*>[\s\S]*?<\s*/\s*iframe\s*>',
        caseSensitive: false,
      ),
      '',
    );

    // Remove inline event handlers like onload=, onclick=, etc.
    out = out.replaceAllMapped(
      RegExp(
        r'\s+on[a-zA-Z]+\s*=\s*(["\"][^"\"]*["\"]|[^\s>]+)',
        caseSensitive: false,
      ),
      (m) => '',
    );

    // Remove external CSS links
    out = out.replaceAll(
      RegExp(
        r'<\s*link[^>]*rel\s*=\s*(["\"])stylesheet\1[^>]*>',
        caseSensitive: false,
      ),
      '',
    );

    // Dangerous attributes: javascript: urls
    out = out.replaceAllMapped(
      RegExp(r'href\s*=\s*(["\"])javascript:[^\1]*\1', caseSensitive: false),
      (m) => '',
    );

    // Handle remote <img src="http/https">
    bool foundRemote = false;
    // Block data: images by default (allow only cid:)
    out = out.replaceAllMapped(
      RegExp(
        r'<\s*img([^>]*?)src\s*=\s*(["\"])(data:[^"\"]+)\2([^>]*)>',
        caseSensitive: false,
      ),
      (m) {
        return ''; // block data URLs
      },
    );

    // Remove srcset entirely to avoid remote fetches
    out = out.replaceAll(
      RegExp(
        r'\s+srcset\s*=\s*(["\"][^"\"]*["\"]|[^\s>]+)',
        caseSensitive: false,
      ),
      '',
    );

    // Remove formaction attribute
    out = out.replaceAll(
      RegExp(
        r'\s+formaction\s*=\s*(["\"][^"\"]*["\"]|[^\s>]+)',
        caseSensitive: false,
      ),
      '',
    );

    // Strip style attributes containing url()
    out = out.replaceAllMapped(
      RegExp(
        r'\s+style\s*=\s*(["\"][^"\"]*[Uu][Rr][Ll]\([^\)]*\)[^"\"]*["\"])',
        caseSensitive: false,
      ),
      (m) => '',
    );

    out = out.replaceAllMapped(
      RegExp(
        r'<\s*img([^>]*?)src\s*=\s*(["\"])(http[s]?://[^"\"]+)\2([^>]*)>',
        caseSensitive: false,
      ),
      (m) {
        foundRemote = true;
        if (allowRemote) {
          return m.group(0)!; // keep
        } else {
          return '';
        }
      },
    );

    return SanitizationResult(out, foundRemote && allowRemote);
  }
}
