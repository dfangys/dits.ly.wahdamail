import 'dart:convert';
import 'package:enough_mail/enough_mail.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

class EnhancedHtmlResult {
  final String html;
  final bool hadExternalImages;
  final bool hasIframes;
  EnhancedHtmlResult({required this.html, required this.hadExternalImages, required this.hasIframes});
}

class HtmlEnhancer {
  static EnhancedHtmlResult enhanceEmailHtml({
    required MimeMessage message,
    required String rawHtml,
    required bool darkMode,
    required bool blockRemoteImages,
    required double deviceWidthPx,
  }) {
    try {
      final doc = html_parser.parse(rawHtml);

      _sanitize(doc);

      // Before blocking, detect whether there are any external images
      final hadExternal = doc.querySelectorAll('img[src]').any((img) {
        final src = img.attributes['src']?.trim() ?? '';
        return src.startsWith('http://') || src.startsWith('https://');
      });

      final hasIframes = doc.querySelector('iframe') != null;

      _rewriteCidImagesInDom(doc, message);
      if (blockRemoteImages) {
        _blockRemoteImages(doc);
      }

      _collapsePictureAndSrcset(doc, deviceWidthPx: deviceWidthPx);
      _applyBaseInlineStyles(doc, darkMode: darkMode);

      return EnhancedHtmlResult(
        html: doc.body?.innerHtml ?? rawHtml,
        hadExternalImages: hadExternal,
        hasIframes: hasIframes,
      );
    } catch (_) {
      return EnhancedHtmlResult(html: rawHtml, hadExternalImages: false, hasIframes: false);
    }
  }

  static void _sanitize(dom.Document doc) {
    for (final el in doc.querySelectorAll('script, object, embed')) {
      el.remove();
    }
    for (final el in doc.querySelectorAll('[onload], [onclick], [onerror], [onmouseover], [onfocus], [onmouseenter], [onmouseleave]')) {
      final keys = List<String>.from(el.attributes.keys);
      for (final k in keys) {
        if (k.toLowerCase().startsWith('on')) {
          el.attributes.remove(k);
        }
      }
    }
    for (final a in doc.querySelectorAll('a[href]')) {
      final href = a.attributes['href'] ?? '';
      if (href.trim().toLowerCase().startsWith('javascript:')) {
        a.attributes.remove('href');
      }
    }
  }

  static void _rewriteCidImagesInDom(dom.Document doc, MimeMessage message) {
    final cidToData = <String, String>{};

    void collectParts(MimePart part) {
      final children = part.parts ?? const <MimePart>[];
      for (final p in children) {
        final cidRaw = p.getHeaderValue('content-id');
        final mimeType = p.mediaType.toString();
        if (cidRaw != null && mimeType.startsWith('image/')) {
          final cid = cidRaw.replaceAll('<', '').replaceAll('>', '');
          try {
            final bytes = p.decodeContentBinary();
            if (bytes != null) {
              final b64 = base64Encode(bytes);
              cidToData[cid] = 'data:$mimeType;base64,$b64';
            }
          } catch (_) {}
        }
        collectParts(p);
      }
    }

    collectParts(message);
    if (cidToData.isEmpty) return;

    for (final img in doc.querySelectorAll('img[src]')) {
      final src = img.attributes['src'] ?? '';
      if (src.startsWith('cid:')) {
        final key = src.substring(4);
        final data = cidToData[key];
        if (data != null) {
          img.attributes['src'] = data;
        }
      }
    }
  }

  static void _blockRemoteImages(dom.Document doc) {
    const spacer = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==';
    for (final img in doc.querySelectorAll('img[src]')) {
      final src = (img.attributes['src'] ?? '').trim();
      if (src.startsWith('http://') || src.startsWith('https://')) {
        img.attributes['src'] = spacer;
      }
    }
    for (final source in doc.querySelectorAll('source[srcset]')) {
      source.attributes['srcset'] = '';
    }
  }

  static void _collapsePictureAndSrcset(dom.Document doc, {required double deviceWidthPx}) {
    for (final picture in doc.querySelectorAll('picture')) {
      final img = picture.querySelector('img');
      String? bestSrc;
      for (final source in picture.querySelectorAll('source')) {
        final srcset = source.attributes['srcset'];
        if (srcset != null && srcset.isNotEmpty) {
          bestSrc = _pickFromSrcset(srcset, deviceWidthPx: deviceWidthPx);
          if (bestSrc != null) break;
        }
      }
      if (bestSrc == null && img != null) {
        final srcset = img.attributes['srcset'];
        if (srcset != null) {
          bestSrc = _pickFromSrcset(srcset, deviceWidthPx: deviceWidthPx);
        }
      }
      if (bestSrc != null && img != null) {
        img.attributes['src'] = bestSrc;
        img.attributes.remove('srcset');
      }
    }

    for (final img in doc.querySelectorAll('img[srcset]')) {
      final srcset = img.attributes['srcset'];
      if (srcset != null) {
        final best = _pickFromSrcset(srcset, deviceWidthPx: deviceWidthPx);
        if (best != null) {
          img.attributes['src'] = best;
        }
        img.attributes.remove('srcset');
      }
    }
  }

  static String? _pickFromSrcset(String srcset, {required double deviceWidthPx}) {
    final candidates = srcset.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    String? best;
    double bestScore = -1;
    for (final c in candidates) {
      final parts = c.split(RegExp(r"\s+"));
      final url = parts[0];
      double score = 0;
      if (parts.length > 1) {
        final d = parts[1];
        if (d.endsWith('x')) {
          final m = double.tryParse(d.substring(0, d.length - 1));
          if (m != null) score = m;
        } else if (d.endsWith('w')) {
          final w = double.tryParse(d.substring(0, d.length - 1));
          if (w != null) {
            score = (deviceWidthPx - (w)).abs();
            score = 100000 - score;
          }
        }
      }
      if (score > bestScore) {
        best = url;
        bestScore = score;
      }
    }
    return best;
  }

  static void _applyBaseInlineStyles(dom.Document doc, {required bool darkMode}) {
    for (final img in doc.querySelectorAll('img')) {
      _mergeStyle(img, {
        'max-width': '100%',
        'height': 'auto',
      });
    }
    for (final pre in doc.querySelectorAll('pre, code')) {
      _mergeStyle(pre, {
        'white-space': 'pre-wrap',
        'word-break': 'break-word',
      });
    }
    for (final a in doc.querySelectorAll('a')) {
      _mergeStyle(a, {
        'text-decoration': 'none',
      });
    }
    for (final bq in doc.querySelectorAll('blockquote')) {
      _mergeStyle(bq, {
        'border-left': '4px solid #1a73e8',
        'padding': '8px 12px',
        'margin': '8px 0',
        'background': darkMode ? '#2a2d32' : '#f3f6fb',
      });
    }
  }

  static void _mergeStyle(dom.Element el, Map<String, String> additions) {
    final existing = el.attributes['style'] ?? '';
    final map = <String, String>{};
    for (final kv in existing.split(';')) {
      final p = kv.split(':');
      if (p.length == 2) {
        map[p[0].trim()] = p[1].trim();
      }
    }
    map.addAll(additions);
    final rebuilt = map.entries.map((e) => '${e.key}: ${e.value}').join('; ');
    el.attributes['style'] = rebuilt;
  }
}

