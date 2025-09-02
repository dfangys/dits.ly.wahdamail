import 'dart:io';
import 'dart:convert';
import 'package:wahda_bank/services/message_content_store.dart';

class OfflineHttpServer {
  OfflineHttpServer._();
  static final OfflineHttpServer instance = OfflineHttpServer._();

  HttpServer? _server;
  int? _port;

  int? get port => _port;

  Future<int> start() async {
    if (_server != null) return _port!;
    final srv = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = srv;
    _port = srv.port;

    srv.listen((HttpRequest req) async {
      try {
        final uri = req.uri;
        if (uri.path == '/ping') {
          req.response
            ..statusCode = 200
            ..headers.set(
              HttpHeaders.contentTypeHeader,
              'text/plain; charset=utf-8',
            )
            ..write('ok');
          await req.response.close();
          return;
        }

        // Route: /attachment/{account}/{box}/{uidValidity}/{uid}?cid=...&name=...&download=0|1
        final segs = uri.pathSegments;
        if (segs.length >= 5 && segs[0] == 'attachment') {
          final account = Uri.decodeComponent(segs[1]);
          final box = Uri.decodeComponent(segs[2]);
          final uidValidity = int.tryParse(segs[3]) ?? 0;
          final uid = int.tryParse(segs[4]) ?? -1;
          final cidQ = uri.queryParameters['cid'];
          final nameQ = uri.queryParameters['name'];
          final download = uri.queryParameters['download'] == '1';

          final store = MessageContentStore.instance;
          var cached = await store.getContent(
            accountEmail: account,
            mailboxPath: box,
            uidValidity: uidValidity,
            uid: uid,
          );
          // Hot-restart fallback: try any uid_validity if not found or empty
          final needsFallback = (cached?.attachments.isEmpty ?? true);
          if (needsFallback) {
            try {
              cached = await store.getContentAnyUidValidity(
                accountEmail: account,
                mailboxPath: box,
                uid: uid,
              );
            } catch (_) {}
          }
          if (cached == null) {
            req.response.statusCode = 404;
            await req.response.close();
            return;
          }

          // Find attachment by CID or filename
          String norm(String? s) =>
              (s ?? '').replaceAll('<', '').replaceAll('>', '').trim();
          final cid = norm(cidQ);
          final name = nameQ == null ? null : Uri.decodeComponent(nameQ);

          final resolved = cached;
          var att = resolved.attachments.firstWhere(
            (a) => cid.isNotEmpty && norm(a.contentId) == cid,
            orElse:
                () => resolved.attachments.firstWhere(
                  (a) => name != null && a.fileName == name,
                  orElse:
                      () => const CachedAttachment(
                        contentId: null,
                        fileName: '',
                        mimeType: 'application/octet-stream',
                        sizeBytes: 0,
                        isInline: false,
                        filePath: '',
                      ),
                ),
          );
          if (att.filePath.isEmpty) {
            // Serve a 1x1 transparent GIF placeholder to avoid broken image UX
            _serveSpacerGif(req);
            return;
          }

          final file = File(att.filePath);
          if (!await file.exists()) {
            _serveSpacerGif(req);
            return;
          }

          final mime =
              att.mimeType.isNotEmpty
                  ? att.mimeType
                  : 'application/octet-stream';
          req.response.headers.set(HttpHeaders.contentTypeHeader, mime);
          final disp = download ? 'attachment' : 'inline';
          final safeName = att.fileName.isEmpty ? 'attachment' : att.fileName;
          req.response.headers.set(
            'content-disposition',
            "$disp; filename=\"$safeName\"",
          );
          try {
            final stat = await file.stat();
            req.response.headers.set(
              HttpHeaders.contentLengthHeader,
              stat.size.toString(),
            );
          } catch (_) {}

          await req.response.addStream(file.openRead());
          await req.response.close();
          return;
        }

        // Route: /message/{account}/{box}/{uidValidity}/{uid}.html?allowRemote=0|1
        if (segs.length == 5 &&
            segs[0] == 'message' &&
            segs[4].endsWith('.html')) {
          final account = Uri.decodeComponent(segs[1]);
          final box = Uri.decodeComponent(segs[2]);
          final uidValidity = int.tryParse(segs[3]) ?? 0;
          final uid = int.tryParse(segs[4].replaceAll('.html', '')) ?? -1;
          final allowRemote = uri.queryParameters['allowRemote'] == '1';

          final store = MessageContentStore.instance;
          var cached = await store.getContent(
            accountEmail: account,
            mailboxPath: box,
            uidValidity: uidValidity,
            uid: uid,
          );
          if (cached == null) {
            try {
              cached = await store.getContentAnyUidValidity(
                accountEmail: account,
                mailboxPath: box,
                uid: uid,
              );
            } catch (_) {}
          }

          String? fileBody;
          // Prefer the on-disk cached HTML if present and meaningful
          final htmlPath = cached?.htmlFilePath;
          if (htmlPath != null && htmlPath.isNotEmpty) {
            try {
              final f = File(htmlPath);
              if (await f.exists()) {
                var s = await f.readAsString();
                if (_hasMeaningfulContent(s)) {
                  // Rewrite cid: URLs to local attachments
                  s = _rewriteCidToLocal(s, account, box, uidValidity, uid);
                  fileBody = s;
                }
              }
            } catch (_) {}
          }

          String body;
          String source;
          if (fileBody != null) {
            // Optionally adjust CSP for allowRemote by swapping img-src line
            if (allowRemote) {
              body = _tweakCspForRemote(fileBody, allowRemote: true);
            } else {
              body = _tweakCspForRemote(fileBody, allowRemote: false);
            }
            source = 'file';
          } else {
            // Fallback to sanitized inline (as stored); wrap with CSP and CSS
            final inner = cached?.htmlSanitizedBlocked ?? '';
            final innerRewritten = _rewriteCidToLocal(
              inner,
              account,
              box,
              uidValidity,
              uid,
            );
            if (innerRewritten.trim().isEmpty) {
              final plain = cached?.plainText ?? '';
              final pre = '<pre class="wb-pre">${_escapeHtml(plain)}</pre>';
              body = _wrapHtml(pre, allowRemote: allowRemote);
            } else {
              body = _wrapHtml(innerRewritten, allowRemote: allowRemote);
            }
            source = 'inline';
          }

          req.response.headers.set(
            HttpHeaders.contentTypeHeader,
            'text/html; charset=utf-8',
          );
          req.response.headers.set('X-From-Cache', source);
          req.response.write(body);
          await req.response.close();
          return;
        }

        req.response.statusCode = 404;
        await req.response.close();
      } catch (_) {
        try {
          req.response.statusCode = 500;
          await req.response.close();
        } catch (_) {}
      }
    });

    return _port!;
  }

  bool _hasMeaningfulContent(String doc) {
    try {
      final m = RegExp(
        r'<div class=\"wb-container\">([\s\S]*?)<\/div>',
        caseSensitive: false,
      ).firstMatch(doc);
      final inner = (m?.group(1) ?? '').replaceAll(RegExp(r'\s+'), '');
      return inner.length > 50;
    } catch (_) {
      return false;
    }
  }

  String _tweakCspForRemote(String html, {required bool allowRemote}) {
    try {
      final allow = "img-src 'self' data: about: cid: http: https:";
      final block = "img-src 'self' data: about: cid:";
      if (allowRemote) {
        if (html.contains(block)) {
          return html.replaceAll(block, allow);
        }
      } else {
        if (html.contains(allow)) {
          return html.replaceAll(allow, block);
        }
      }
      return html;
    } catch (_) {
      return html;
    }
  }

  String _rewriteCidToLocal(
    String html,
    String account,
    String box,
    int uidValidity,
    int uid,
  ) {
    try {
      final base =
          '/attachment/'
          '${Uri.encodeComponent(account)}/'
          '${Uri.encodeComponent(box)}/'
          '$uidValidity/$uid';
      html = html.replaceAllMapped(
        RegExp(r'src\s*=\s*"cid:([^"]+)"', caseSensitive: false),
        (m) {
          final cid = Uri.encodeComponent(
            m.group(1)!.replaceAll('<', '').replaceAll('>', ''),
          );
          return 'src="http://127.0.0.1:$_port$base?cid=$cid"';
        },
      );
      html = html.replaceAllMapped(
        RegExp(r"src\s*=\s*'cid:([^']+)'", caseSensitive: false),
        (m) {
          final cid = Uri.encodeComponent(
            m.group(1)!.replaceAll('<', '').replaceAll('>', ''),
          );
          return "src='http://127.0.0.1:$_port$base?cid=$cid'";
        },
      );
      return html;
    } catch (_) {
      return html;
    }
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  void _serveSpacerGif(HttpRequest req) {
    try {
      // 1x1 transparent GIF
      const b64 = 'R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==';
      final bytes = base64Decode(b64);
      req.response.headers.set(HttpHeaders.contentTypeHeader, 'image/gif');
      req.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      req.response.add(bytes);
    } catch (_) {
      req.response.statusCode = 404;
    } finally {
      req.response.close();
    }
  }

  String _wrapHtml(String innerHtml, {required bool allowRemote}) {
    final cspImg =
        allowRemote
            ? "img-src 'self' data: about: cid: http: https:;"
            : "img-src 'self' data: about: cid:;";
    final csp = [
      "default-src 'none';",
      "base-uri 'none';",
      "form-action 'none';",
      "frame-ancestors 'none';",
      "script-src 'none';",
      "object-src 'none';",
      "connect-src 'none';",
      cspImg,
      "style-src 'unsafe-inline';",
      "media-src data:;",
      "font-src data:;",
      "frame-src about:;",
    ].join(' ');

    const css = '''
      :root { color-scheme: light; }
      html, body { margin:0; padding:0; width:100%; overflow-x:hidden; background:#ffffff; color:#1b1c1f; }
      * { box-sizing: border-box; }
      .wb-container { max-width: 100vw; width:100%; overflow-x:hidden; }
      body { font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Helvetica Neue', Arial, sans-serif; line-height:1.5; font-size:15px; overflow-wrap:anywhere; word-break:break-word; -webkit-text-size-adjust: 100%; }
      img, video, iframe { max-width:100% !important; height:auto !important; }
      table { max-width:100% !important; width:100% !important; }
      td, th { word-break: break-word; }
      pre, code { white-space:pre-wrap !important; word-break:break-word !important; }
      a { text-decoration:none; color:#1a73e8; }
      blockquote { border-left:4px solid #1a73e8; background:#f3f6fb; padding:8px 12px; margin:8px 0; }
    ''';

    return '<!doctype html>'
        '<html>'
        '<head>'
        '<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />'
        '<meta http-equiv="Content-Security-Policy" content="$csp" />'
        '<style>$css</style>'
        '</head>'
        '<body class="wb-body"><div class="wb-container">$innerHtml</div></body>'
        '</html>';
  }
}
