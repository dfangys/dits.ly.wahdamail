import 'dart:convert';
import 'dart:io';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wahda_bank/services/sender_trust.dart';

class EnterpriseMessageViewer extends StatefulWidget {
  const EnterpriseMessageViewer({
    super.key,
    required this.mimeMessage,
    this.enableDarkMode = false,
    this.blockExternalImages = true,
    this.textScale = 1.0,
    this.initialHtml,
    this.initialHtmlPath,
  });

  final MimeMessage mimeMessage;
  final bool enableDarkMode;
  final bool blockExternalImages;
  final double textScale;
  final String? initialHtml;
  final String? initialHtmlPath;

  @override
  State<EnterpriseMessageViewer> createState() => _EnterpriseMessageViewerState();
}

class _EnterpriseMessageViewerState extends State<EnterpriseMessageViewer> {
  InAppWebViewController? _controller;
  bool _blocked = true;
  late String _preparedHtml;
  double _contentHeight = 600;
  String _senderKey = '';

  @override
  void initState() {
    super.initState();
    _senderKey = _extractSenderKey(widget.mimeMessage);
    final trusted = SenderTrustService.instance.isTrusted(_senderKey);
    _blocked = widget.blockExternalImages && !trusted;
    _preparedHtml = _buildPreparedHtml(blockRemote: _blocked);
  }

  @override
  void didUpdateWidget(covariant EnterpriseMessageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newSender = _extractSenderKey(widget.mimeMessage);
    if (newSender != _senderKey) {
      _senderKey = newSender;
      final trusted = SenderTrustService.instance.isTrusted(_senderKey);
      _blocked = widget.blockExternalImages && !trusted;
    }
    if (oldWidget.mimeMessage != widget.mimeMessage ||
        oldWidget.enableDarkMode != widget.enableDarkMode ||
        oldWidget.textScale != widget.textScale ||
        oldWidget.blockExternalImages != widget.blockExternalImages) {
      _preparedHtml = _buildPreparedHtml(blockRemote: _blocked);
      _reloadHtml();
    }
  }

  @override
  Widget build(BuildContext context) {
    final blockers = _contentBlockersFor(_blocked);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_blocked) _externalImagesBanner(),
        SizedBox(
          height: _contentHeight.clamp(300, 5000),
          child: InAppWebView(
            initialData: InAppWebViewInitialData(data: _preparedHtml, baseUrl: WebUri("about:blank")),
            initialSettings: InAppWebViewSettings(
              // Security posture
              javaScriptEnabled: false,
              incognito: true,
              cacheEnabled: false,
              clearCache: true,
              clearSessionCache: true,
              thirdPartyCookiesEnabled: false,
              allowFileAccessFromFileURLs: false,
              allowUniversalAccessFromFileURLs: false,
              mediaPlaybackRequiresUserGesture: true,

              // UX
              transparentBackground: true,
              supportZoom: true,
              builtInZoomControls: true,
              displayZoomControls: false,
              disableHorizontalScroll: true,

              // Privacy
              contentBlockers: blockers,
            ),
            onWebViewCreated: (c) async {
              _controller = c;
              try {
                await InAppWebViewController.clearAllCache();
              } catch (_) {}
              // If an offline HTML file path is provided and exists, load it immediately; otherwise rely on prepared HTML
              final path = widget.initialHtmlPath;
              if (path != null && path.isNotEmpty) {
                try {
                  final exists = File(path).existsSync();
                  if (exists) {
                    await _controller?.loadUrl(urlRequest: URLRequest(url: WebUri('file://$path')));
                  }
                } catch (_) {}
              }
            },
            onContentSizeChanged: (controller, oldSize, newSize) {
              setState(() {
                // Fit to content; enforce sensible minimum; no artificial maximum
                _contentHeight = newSize.height < 300 ? 300 : newSize.height;
              });
            },
            shouldOverrideUrlLoading: (controller, nav) async {
              final url = nav.request.url?.toString() ?? '';
              if (url.isEmpty) return NavigationActionPolicy.CANCEL;
              // Allow internal about:/data: resources
              if (url.startsWith('about:') || url.startsWith('data:')) {
                return NavigationActionPolicy.ALLOW;
              }
              // External links: open in system browser
              if (url.startsWith('http://') || url.startsWith('https://')) {
                try {
                  await launchUrlString(url, mode: LaunchMode.externalApplication);
                } catch (_) {}
                return NavigationActionPolicy.CANCEL;
              }
              return NavigationActionPolicy.CANCEL;
            },
          ),
        ),
      ],
    );
  }

  List<ContentBlocker> _contentBlockersFor(bool blocked) {
    final list = <ContentBlocker>[
      // Always block scripts/objects regardless of JS toggle
      ContentBlocker(
        trigger: ContentBlockerTrigger(
          urlFilter: ".*",
          resourceType: [
            ContentBlockerTriggerResourceType.SCRIPT,
          ],
        ),
        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
      ),
    ];
    if (blocked) {
      list.addAll([
        // Block remote images; data: allowed by rewrite
        ContentBlocker(
          trigger: ContentBlockerTrigger(
            urlFilter: r"^https?://.*",
            resourceType: [ContentBlockerTriggerResourceType.IMAGE],
          ),
          action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
        ),
        // Block media by default
        ContentBlocker(
          trigger: ContentBlockerTrigger(
            urlFilter: r"^https?://.*",
            resourceType: [
              ContentBlockerTriggerResourceType.MEDIA,
            ],
          ),
          action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
        ),
      ]);
    }
    return list;
  }

  Widget _externalImagesBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.privacy_tip_outlined, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'External images are blocked for privacy. You can load once or trust this sender.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () async {
              setState(() {
                _blocked = false;
                _preparedHtml = _buildPreparedHtml(blockRemote: _blocked);
              });
              try {
                await _controller?.setSettings(settings: InAppWebViewSettings(contentBlockers: []));
              } catch (_) {}
              await _reloadHtml();
            },
            child: const Text('Load once'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              try {
                await SenderTrustService.instance.trustSender(_senderKey, trusted: true);
              } catch (_) {}
              setState(() {
                _blocked = false;
                _preparedHtml = _buildPreparedHtml(blockRemote: _blocked);
              });
              try {
                await _controller?.setSettings(settings: InAppWebViewSettings(contentBlockers: []));
              } catch (_) {}
              await _reloadHtml();
            },
            child: const Text('Always allow'),
          ),
        ],
      ),
    );
  }

  Future<void> _reloadHtml() async {
    try {
      // Prefer reloading from file if provided and exists; otherwise fallback to prepared HTML
      final path = widget.initialHtmlPath;
      if (path != null && path.isNotEmpty && File(path).existsSync()) {
        await _controller?.loadUrl(urlRequest: URLRequest(url: WebUri('file://$path')));
      } else {
        await _controller?.loadData(data: _preparedHtml, baseUrl: WebUri("about:blank"));
      }
    } catch (_) {}
  }

  String _buildPreparedHtml({required bool blockRemote}) {
    // Prefer provided offline/sanitized HTML or file path if available
    if (widget.initialHtmlPath != null && widget.initialHtmlPath!.isNotEmpty) {
      // Only favor the path if the file actually exists; otherwise fall back to initialHtml/raw
      try {
        if (File(widget.initialHtmlPath!).existsSync()) {
          // Placeholder while file:// is loaded in onWebViewCreated/_reloadHtml
          final css = _baseCss(widget.enableDarkMode, widget.textScale);
          final placeholder = '<div style="padding:16px;color:#777;font-size:13px;">Loading cached content…</div>';
          return _wrapHtml(_csp(blockRemote), '<style>$css</style>\n$placeholder');
        }
      } catch (_) {}
    }
    if (widget.initialHtml != null && widget.initialHtml!.trim().isNotEmpty) {
      final css = _baseCss(widget.enableDarkMode, widget.textScale);
      return _wrapHtml(_csp(blockRemote), '<style>$css</style>\n${widget.initialHtml!}');
    }

    final rawHtml = widget.mimeMessage.decodeTextHtmlPart();
    if (rawHtml == null || rawHtml.trim().isEmpty) {
      final plain = widget.mimeMessage.decodeTextPlainPart() ?? '';
      return _wrapHtml(_csp(blockRemote), '<pre class="wb-pre">${_escapeHtml(plain)}</pre>');
    }

    String html = rawHtml;
    html = _stripDangerous(html);
    html = _rewriteCidImages(html, widget.mimeMessage);
    if (blockRemote) {
      html = _blockRemoteImages(html);
    }

    final css = _baseCss(widget.enableDarkMode, widget.textScale);
    return _wrapHtml(_csp(blockRemote), '<style>$css</style>\n$html');
  }

  String _csp(bool blocked) {
    final imgSrc = blocked ? "img-src 'self' data: about: cid:;" : "img-src 'self' data: about: cid: http: https:;";
    // Note: 'self' maps to about: context; no external origins due to baseUrl about:blank
    return [
      "default-src 'none';",
      "base-uri 'none';",
      "form-action 'none';",
      "frame-ancestors 'none';",
      "script-src 'none';",
      "object-src 'none';",
      "connect-src 'none';",
      imgSrc,
      "style-src 'unsafe-inline';",
      "media-src data:;",
      "font-src data:;",
      "frame-src about:;",
    ].join(' ');
  }

  String _wrapHtml(String csp, String body) {
    return '<!doctype html>'
        '<html>'
        '<head>'
        '<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />'
        '<meta http-equiv="Content-Security-Policy" content="$csp" />'
        '</head>'
        '<body class="wb-body"><div class="wb-container">$body</div></body>'
        '</html>';
  }

  String _baseCss(bool dark, double scale) {
    final bg = dark ? '#0e0f12' : '#ffffff';
    final fg = dark ? '#e7e7e9' : '#1b1c1f';
    const link = '#1a73e8';
    final quote = dark ? '#2a2d32' : '#f3f6fb';
    final px = (15 * scale).toStringAsFixed(1);
    return '''
      :root { color-scheme: ${dark ? 'dark' : 'light'}; }
      html, body { background:$bg; color:$fg; margin:0; padding:0; width:100%; overflow-x:hidden; }
      * { box-sizing: border-box; }
      .wb-container { max-width: 100vw; width:100%; overflow-x:hidden; }
      body { font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, 'Helvetica Neue', Arial, sans-serif; line-height:1.5; font-size:${px}px; overflow-wrap:anywhere; word-break:break-word; -webkit-text-size-adjust: 100%; }
      img, video, iframe { max-width:100% !important; height:auto !important; }
      table { max-width:100% !important; width:100% !important; }
      td, th { word-break: break-word; }
      pre, code { white-space:pre-wrap !important; word-break:break-word !important; }
      blockquote { border-left:4px solid $link; background:$quote; padding:8px 12px; margin:8px 0; }
      a { color:$link; text-decoration:none; }
      a:hover { text-decoration:underline; }
      .wb-pre { white-space: pre-wrap; }
    ''';
  }

  String _stripDangerous(String html) {
    try {
      html = html.replaceAll(RegExp(r'<script[\s\S]*?>[\s\S]*?<\/script>', caseSensitive: false), '');
      html = html.replaceAll(RegExp(r'<object[\s\S]*?>[\s\S]*?<\/object>', caseSensitive: false), '');
      html = html.replaceAll(RegExp(r'<embed[\s\S]*?>', caseSensitive: false), '');
      html = html.replaceAll(RegExp(r'on\w+\s*=\s*"[^"]*"', caseSensitive: false), '');
      html = html.replaceAll(RegExp(r"on\w+\s*=\s*'[^']*'", caseSensitive: false), '');
      html = html.replaceAll(RegExp(r'href\s*=\s*"javascript:[^"]*"', caseSensitive: false), '');
      html = html.replaceAll(RegExp(r"href\s*=\s*'javascript:[^']*'", caseSensitive: false), '');
      return html;
    } catch (_) {
      return html;
    }
  }

  String _blockRemoteImages(String html) {
    const spacer = 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==';
    // Replace direct img src
    html = html.replaceAllMapped(
      RegExp(r'<img([^>]*?)src\s*=\s*\"https?:[^\"]*\"([^>]*)>', caseSensitive: false),
      (m) => '<img${m.group(1) ?? ''}src="$spacer"${m.group(2) ?? ''}>',
    );
    html = html.replaceAllMapped(
      RegExp(r"<img([^>]*?)src\s*=\s*'https?:[^']*'([^>]*)>", caseSensitive: false),
      (m) => "<img${m.group(1) ?? ''}src='$spacer'${m.group(2) ?? ''}>",
    );
    // Neutralize img srcset
    html = html.replaceAllMapped(
      RegExp(r'<img([^>]*?)srcset\s*=\s*\"[^\"]*\"', caseSensitive: false),
      (m) => '<img${m.group(1) ?? ''}srcset="">',
    );
    html = html.replaceAllMapped(
      RegExp(r"<img([^>]*?)srcset\s*=\s*'[^']*'", caseSensitive: false),
      (m) => "<img${m.group(1) ?? ''}srcset=''>",
    );
    // Neutralize lazy-loading attributes
    html = html.replaceAllMapped(
      RegExp(r'<img([^>]*?)(data-(?:src|original|lazy-src))\s*=\s*\"https?:[^\"]*\"', caseSensitive: false),
      (m) => '<img${m.group(1) ?? ''}${m.group(2)}="$spacer"',
    );
    html = html.replaceAllMapped(
      RegExp(r"<img([^>]*?)(data-(?:src|original|lazy-src))\s*=\s*'https?:[^']*'", caseSensitive: false),
      (m) => "<img${m.group(1) ?? ''}${m.group(2)}='$spacer'",
    );
    // Neutralize <source srcset> within <picture>
    html = html.replaceAllMapped(
      RegExp(r'<source([^>]*?)srcset\s*=\s*\"https?:[^\"]*\"', caseSensitive: false),
      (m) => '<source${m.group(1) ?? ''}srcset="">',
    );
    html = html.replaceAllMapped(
      RegExp(r"<source([^>]*?)srcset\s*=\s*'https?:[^']*'", caseSensitive: false),
      (m) => "<source${m.group(1) ?? ''}srcset=''>",
    );
    return html;
  }

  String _rewriteCidImages(String html, MimeMessage message) {
    try {
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
      if (cidToData.isEmpty) return html;

      html = html.replaceAllMapped(
        RegExp(r'src\s*=\s*"cid:([^"]+)"', caseSensitive: false),
        (m) {
          final key = m.group(1)!;
          final data = cidToData[key] ?? m.group(0)!;
          return 'src="$data"';
        },
      );
      html = html.replaceAllMapped(
        RegExp(r"src\s*=\s*'cid:([^']+)'", caseSensitive: false),
        (m) {
          final key = m.group(1)!;
          final data = cidToData[key] ?? m.group(0)!;
          return "src='$data'";
        },
      );

      return html;
    } catch (_) {
      return html;
    }
  }

  String _escapeHtml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  String _extractSenderKey(MimeMessage msg) {
    try {
      String? email;
      final from = msg.from;
      if (from != null && from.isNotEmpty) {
        email = from.first.email;
      } else {
        final replyTo = msg.replyTo;
        if (replyTo != null && replyTo.isNotEmpty) {
          email = replyTo.first.email;
        }
      }
      return (email ?? 'unknown@sender').toLowerCase();
    } catch (_) {
      return 'unknown@sender';
    }
  }
}

