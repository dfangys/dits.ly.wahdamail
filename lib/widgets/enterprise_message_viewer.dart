import 'dart:convert';
import 'dart:io';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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
    this.preferInline = false,
  });

  final MimeMessage mimeMessage;
  final bool enableDarkMode;
  final bool blockExternalImages;
  final double textScale;
  final String? initialHtml;
  final String? initialHtmlPath;
  final bool preferInline;

  @override
  State<EnterpriseMessageViewer> createState() =>
      _EnterpriseMessageViewerState();
}

class _EnterpriseMessageViewerState extends State<EnterpriseMessageViewer> {
  InAppWebViewController? _controller;
  bool _blocked = true;
  late String _preparedHtml;
  late String _inlineHtml; // full inline HTML fallback
  double _contentHeight = 1; // start minimal; expand when content reports size
  String _senderKey = '';
  bool _isReady = false; // overlay loader until we know content is rendered
  bool _expectFile = false; // true when we plan to load a file:// path
  double _lastMeasuredHeight = 0; // raw content height from webview
  bool _usedInlineFallback = false; // to avoid infinite reload loops

  @override
  void initState() {
    super.initState();
    _senderKey = _extractSenderKey(widget.mimeMessage);
    final trusted = SenderTrustService.instance.isTrusted(_senderKey);
    _blocked = widget.blockExternalImages && !trusted;
    _inlineHtml = _buildInlineHtml(blockRemote: _blocked);
    _preparedHtml = _buildPreparedHtml(blockRemote: _blocked);

    // Decide if we expect a file load; this helps avoid premature loader removal
    try {
      final p = widget.initialHtmlPath;
      _expectFile =
          !widget.preferInline &&
          p != null &&
          p.isNotEmpty &&
          !p.startsWith('http') &&
          File(p).existsSync();
    } catch (_) {
      _expectFile = false;
    }
    _isReady = false; // start with loader visible

    if (kDebugMode) {
      final uid = widget.mimeMessage.uid;
      final path = widget.initialHtmlPath;
      final htmlLen = _preparedHtml.length;
      int fileSize = -1;
      bool exists = false;
      try {
        if (path != null && path.isNotEmpty) {
          final f = File(path);
          exists = f.existsSync();
          if (exists) fileSize = f.statSync().size;
        }
      } catch (_) {}
      // Debug summary of initial state
      // ignore: avoid_print
      print(
        'VIEWER:init uid=$uid expectFile=$_expectFile path=$path exists=$exists size=$fileSize preparedHtmlLen=$htmlLen blocked=$_blocked dark=${widget.enableDarkMode}',
      );
    }

    // Safety fallback: if the webview does not report size/load events in time,
    // dismiss the overlay to avoid a blank experience.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        if (!_isReady) {
          if (kDebugMode) {
            // ignore: avoid_print
            print(
              'VIEWER:safety_timer uid=${widget.mimeMessage.uid} firing -> dismiss loader',
            );
          }
          setState(() {
            _isReady = true;
          });
        }
      });
    });
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
    // Re-evaluate whether we should expect a file load when props change
    try {
      final p = widget.initialHtmlPath;
      _expectFile =
          !widget.preferInline &&
          p != null &&
          p.isNotEmpty &&
          !p.startsWith('http') &&
          File(p).existsSync();
    } catch (_) {
      _expectFile = false;
    }
    if (oldWidget.mimeMessage != widget.mimeMessage ||
        oldWidget.enableDarkMode != widget.enableDarkMode ||
        oldWidget.textScale != widget.textScale ||
        oldWidget.blockExternalImages != widget.blockExternalImages ||
        oldWidget.initialHtmlPath != widget.initialHtmlPath ||
        oldWidget.initialHtml != widget.initialHtml) {
      _inlineHtml = _buildInlineHtml(blockRemote: _blocked);
      _preparedHtml = _buildPreparedHtml(blockRemote: _blocked);
      _usedInlineFallback = false;
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
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          height: _isReady ? (_contentHeight <= 0 ? 1 : _contentHeight) : 120,
          child: Stack(
            children: [
              InAppWebView(
                initialData: InAppWebViewInitialData(
                  data: _preparedHtml,
                  baseUrl: WebUri("about:blank"),
                ),
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
                  // If an offline HTML file path is provided and exists, load it immediately; otherwise rely on prepared HTML
                  final path = widget.initialHtmlPath;
                  if (kDebugMode) {
                    // ignore: avoid_print
                    print(
                      'VIEWER:onWebViewCreated uid=${widget.mimeMessage.uid} initialHtmlPath=$path',
                    );
                  }
                  if (widget.preferInline) {
                    try {
                      await _controller?.loadData(
                        data: _inlineHtml,
                        baseUrl: WebUri("about:blank"),
                      );
                      if (mounted)
                        setState(() {
                          _expectFile = false;
                          _isReady = true;
                        });
                    } catch (e) {
                      if (kDebugMode) {
                        // ignore: avoid_print
                        print('VIEWER:onWebViewCreated inline load error: $e');
                      }
                    }
                  } else if (path != null && path.isNotEmpty) {
                    // HTTP URL from local server
                    if (path.startsWith('http://') ||
                        path.startsWith('https://')) {
                      try {
                        // If remote images are allowed, prefer inline render to bypass sanitized cached files
                        if (!_blocked) {
                          await _controller?.loadData(
                            data: _inlineHtml,
                            baseUrl: WebUri("about:blank"),
                          );
                          if (mounted)
                            setState(() {
                              _expectFile = false;
                              _isReady = true;
                            });
                        } else {
                          final adjusted = _withAllowRemoteParam(
                            path,
                            allowRemote: !_blocked,
                          );
                          await _controller?.loadUrl(
                            urlRequest: URLRequest(url: WebUri(adjusted)),
                          );
                          if (mounted)
                            setState(() {
                              _expectFile = false;
                            });
                        }
                      } catch (e) {
                        if (kDebugMode) {
                          // ignore: avoid_print
                          print('VIEWER:onWebViewCreated http load error: $e');
                        }
                      }
                    } else {
                      try {
                        final f = File(path);
                        final exists = f.existsSync();
                        final size = exists ? f.statSync().size : -1;
                        if (kDebugMode) {
                          // ignore: avoid_print
                          print(
                            'VIEWER:onWebViewCreated file exists=$exists size=$size',
                          );
                        }
                        if (exists) {
                          // Inspect file inner content; if effectively empty, prefer inline fallback immediately
                          bool useInline = false;
                          String content = '';
                          try {
                            content = f.readAsStringSync();
                            final m = RegExp(
                              r'<div class=\\\"wb-container\\\">([\\s\\S]*?)<\\/div>',
                              caseSensitive: false,
                            ).firstMatch(content);
                            if (m != null) {
                              final innerLen =
                                  (m.group(1) ?? '')
                                      .replaceAll(RegExp(r'\\s+'), '')
                                      .length;
                              if (innerLen < 20) useInline = true;
                            }
                          } catch (_) {}
                          if (useInline) {
                            if (kDebugMode) {
                              // ignore: avoid_print
                              print(
                                'VIEWER:inline_fallback_pre uid=${widget.mimeMessage.uid} (onWebViewCreated)',
                              );
                            }
                            await _controller?.loadData(
                              data: _inlineHtml,
                              baseUrl: WebUri("about:blank"),
                            );
                            if (mounted) {
                              setState(() {
                                _expectFile = false;
                                _usedInlineFallback = true;
                                _isReady = true;
                              });
                            }
                          } else {
                            // iOS: prefer loading file content via loadData to avoid file:// navigation being blocked
                            if (Platform.isIOS) {
                              try {
                                await _controller?.loadData(
                                  data: content,
                                  baseUrl: WebUri("about:blank"),
                                );
                                if (mounted)
                                  setState(() {
                                    _expectFile = false;
                                    _isReady = true;
                                  });
                              } catch (e) {
                                if (kDebugMode) {
                                  print('VIEWER:iOS file loadData error: $e');
                                }
                              }
                            } else {
                              await _controller?.loadUrl(
                                urlRequest: URLRequest(
                                  url: WebUri('file://$path'),
                                ),
                              );
                              // Safety net: if not ready shortly, fallback to inline
                              Future.delayed(
                                const Duration(milliseconds: 800),
                                () async {
                                  if (!mounted) return;
                                  if (!_isReady && _expectFile) {
                                    if (kDebugMode) {
                                      print(
                                        'VIEWER:safety_fallback uid=${widget.mimeMessage.uid} (onWebViewCreated)',
                                      );
                                    }
                                    await _controller?.loadData(
                                      data: _inlineHtml,
                                      baseUrl: WebUri("about:blank"),
                                    );
                                    if (mounted)
                                      setState(() {
                                        _expectFile = false;
                                        _usedInlineFallback = true;
                                        _isReady = true;
                                      });
                                  }
                                },
                              );
                            }
                          }
                        }
                      } catch (e) {
                        if (kDebugMode) {
                          // ignore: avoid_print
                          print('VIEWER:onWebViewCreated loadUrl error: $e');
                        }
                      }
                    }
                  }
                },
                onContentSizeChanged: (controller, oldSize, newSize) {
                  if (kDebugMode) {
                    // ignore: avoid_print
                    print(
                      'VIEWER:onContentSizeChanged uid=${widget.mimeMessage.uid} old=${oldSize.width}x${oldSize.height} new=${newSize.width}x${newSize.height}',
                    );
                  }
                  setState(() {
                    // Fit height exactly to content with no artificial minimum
                    final h = newSize.height;
                    _lastMeasuredHeight = h;
                    _contentHeight = h;
                    // Consider the content ready as soon as a non-trivial height is measured
                    if (h > 1) {
                      _isReady = true;
                    }
                  });
                },
                shouldOverrideUrlLoading: (controller, nav) async {
                  final url = nav.request.url?.toString() ?? '';
                  if (url.isEmpty) return NavigationActionPolicy.CANCEL;
                  // Allow internal about:/data: resources
                  if (url.startsWith('about:') || url.startsWith('data:')) {
                    return NavigationActionPolicy.ALLOW;
                  }
                  // Allow local server URLs to load inside the WebView
                  if (url.startsWith('http://127.0.0.1') ||
                      url.startsWith('http://localhost')) {
                    return NavigationActionPolicy.ALLOW;
                  }
                  // Allow local file URLs for offline HTML
                  if (url.startsWith('file://') ||
                      url.startsWith('filesystem:')) {
                    return NavigationActionPolicy.ALLOW;
                  }
                  // External links: open in system browser
                  if (url.startsWith('http://') || url.startsWith('https://')) {
                    try {
                      await launchUrlString(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (_) {}
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.CANCEL;
                },
                onLoadStop: (controller, url) async {
                  // Hide loader when final content is loaded
                  final s = url.toString();
                  if (kDebugMode) {
                    // ignore: avoid_print
                    print(
                      'VIEWER:onLoadStop uid=${widget.mimeMessage.uid} url=$s expectFile=$_expectFile',
                    );
                  }
                  setState(() {
                    if (_expectFile) {
                      if (s.startsWith('file://')) {
                        _isReady = true;
                      }
                    } else {
                      _isReady = true;
                    }
                  });

                  // Aggressive fallback: if cached file appears effectively empty, reload with full inline HTML
                  try {
                    if (_expectFile && !_usedInlineFallback) {
                      final path = widget.initialHtmlPath;
                      if (path != null && path.isNotEmpty) {
                        final f = File(path);
                        if (f.existsSync()) {
                          String content = '';
                          try {
                            content = f.readAsStringSync();
                          } catch (_) {}
                          int innerLen = -1;
                          try {
                            final m = RegExp(
                              r'<div class=\"wb-container\">([\s\S]*?)<\/div>',
                              caseSensitive: false,
                            ).firstMatch(content);
                            if (m != null) {
                              innerLen =
                                  (m.group(1) ?? '')
                                      .replaceAll(RegExp(r'\s+'), '')
                                      .length;
                            }
                          } catch (_) {}
                          final fallbackByDom = innerLen >= 0 && innerLen < 20;
                          final fallbackByHeight = _lastMeasuredHeight <= 1;
                          if (fallbackByDom || fallbackByHeight) {
                            if (kDebugMode) {
                              // ignore: avoid_print
                              print(
                                'VIEWER:inline_fallback uid=${widget.mimeMessage.uid} byDom=$fallbackByDom byHeight=$fallbackByHeight',
                              );
                            }
                            await _controller?.loadData(
                              data: _inlineHtml,
                              baseUrl: WebUri("about:blank"),
                            );
                            if (mounted) {
                              setState(() {
                                _expectFile = false;
                                _usedInlineFallback = true;
                                _isReady = true;
                              });
                            }
                            return;
                          }
                        }
                      }
                    }
                  } catch (e) {
                    if (kDebugMode) {
                      // ignore: avoid_print
                      print(
                        'VIEWER:inline_fallback error uid=${widget.mimeMessage.uid}: $e',
                      );
                    }
                  }
                },
                onReceivedError: (controller, request, error) async {
                  // Handle navigation errors similarly
                  try {
                    await _controller?.loadData(
                      data: _inlineHtml,
                      baseUrl: WebUri("about:blank"),
                    );
                  } catch (_) {}
                  if (mounted) {
                    setState(() {
                      _isReady = true;
                      _expectFile = false;
                      _usedInlineFallback = true;
                    });
                  }
                },
              ),
              if (!_isReady)
                Positioned.fill(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                ),
            ],
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
          resourceType: [ContentBlockerTriggerResourceType.SCRIPT],
        ),
        action: ContentBlockerAction(type: ContentBlockerActionType.BLOCK),
      ),
    ];
    if (blocked) {
      // We rely on CSP to block remote images; allowing local 127.0.0.1 resources to load.
      // Keep script blocking only.
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
          Icon(
            Icons.privacy_tip_outlined,
            color: Colors.orange.shade700,
            size: 20,
          ),
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
                await _controller?.setSettings(
                  settings: InAppWebViewSettings(contentBlockers: []),
                );
              } catch (_) {}
              await _reloadHtml();
            },
            child: const Text('Load once'),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              try {
                await SenderTrustService.instance.trustSender(
                  _senderKey,
                  trusted: true,
                );
              } catch (_) {}
              setState(() {
                _blocked = false;
                _preparedHtml = _buildPreparedHtml(blockRemote: _blocked);
              });
              try {
                await _controller?.setSettings(
                  settings: InAppWebViewSettings(contentBlockers: []),
                );
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
      if (kDebugMode) {
        final htmlLen = _preparedHtml.length;
        // ignore: avoid_print
        print(
          'VIEWER:_reloadHtml uid=${widget.mimeMessage.uid} path=$path preparedHtmlLen=$htmlLen',
        );
      }
      if (widget.preferInline) {
        await _controller?.loadData(
          data: _inlineHtml,
          baseUrl: WebUri("about:blank"),
        );
        if (mounted)
          setState(() {
            _expectFile = false;
            _isReady = true;
          });
      } else if (path != null &&
          path.isNotEmpty &&
          (path.startsWith('http://') || path.startsWith('https://'))) {
        // If remote images are allowed (not blocked), prefer inline to avoid sanitized cached content
        if (!_blocked) {
          await _controller?.loadData(
            data: _inlineHtml,
            baseUrl: WebUri("about:blank"),
          );
          if (mounted)
            setState(() {
              _expectFile = false;
              _isReady = true;
            });
        } else {
          final adjusted = _withAllowRemoteParam(path, allowRemote: !_blocked);
          await _controller?.loadUrl(
            urlRequest: URLRequest(url: WebUri(adjusted)),
          );
          if (mounted)
            setState(() {
              _expectFile = false;
            });
        }
      } else if (path != null && path.isNotEmpty && File(path).existsSync()) {
        // Inspect file inner content; if effectively empty, prefer inline fallback immediately
        bool useInline = false;
        String content = '';
        try {
          content = File(path).readAsStringSync();
          final m = RegExp(
            r'<div class=\"wb-container\">([\s\S]*?)<\/div>',
            caseSensitive: false,
          ).firstMatch(content);
          if (m != null) {
            final innerLen =
                (m.group(1) ?? '').replaceAll(RegExp(r'\s+'), '').length;
            if (innerLen < 20) useInline = true;
          }
        } catch (_) {}
        if (useInline) {
          if (kDebugMode) {
            // ignore: avoid_print
            print(
              'VIEWER:inline_fallback_pre uid=${widget.mimeMessage.uid} (_reloadHtml)',
            );
          }
          await _controller?.loadData(
            data: _inlineHtml,
            baseUrl: WebUri("about:blank"),
          );
          if (mounted) {
            setState(() {
              _expectFile = false;
              _usedInlineFallback = true;
              _isReady = true;
            });
          }
        } else {
          if (Platform.isIOS) {
            try {
              await _controller?.loadData(
                data: content,
                baseUrl: WebUri("about:blank"),
              );
              if (mounted)
                setState(() {
                  _expectFile = false;
                  _isReady = true;
                });
            } catch (e) {
              if (kDebugMode) {
                print('VIEWER:iOS file loadData error (_reloadHtml): $e');
              }
            }
          } else {
            await _controller?.loadUrl(
              urlRequest: URLRequest(url: WebUri('file://$path')),
            );
            // Safety net: if not ready shortly, fallback to inline
            Future.delayed(const Duration(milliseconds: 800), () async {
              if (!mounted) return;
              if (!_isReady && _expectFile) {
                if (kDebugMode) {
                  print(
                    'VIEWER:safety_fallback uid=${widget.mimeMessage.uid} (_reloadHtml)',
                  );
                }
                await _controller?.loadData(
                  data: _inlineHtml,
                  baseUrl: WebUri("about:blank"),
                );
                if (mounted)
                  setState(() {
                    _expectFile = false;
                    _usedInlineFallback = true;
                    _isReady = true;
                  });
              }
            });
          }
        }
      } else {
        await _controller?.loadData(
          data: _preparedHtml,
          baseUrl: WebUri("about:blank"),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('VIEWER:_reloadHtml error uid=${widget.mimeMessage.uid}: $e');
      }
    }
  }

  String _buildPreparedHtml({required bool blockRemote}) {
    // Prefer provided offline/sanitized HTML or file path if available
    if (widget.preferInline) {
      return _buildInlineHtml(blockRemote: blockRemote);
    }
    if (widget.initialHtmlPath != null && widget.initialHtmlPath!.isNotEmpty) {
      // If it's an HTTP URL, don't show placeholder; inline will render until HTTP load completes
      if (widget.initialHtmlPath!.startsWith('http://') ||
          widget.initialHtmlPath!.startsWith('https://')) {
        return _buildInlineHtml(blockRemote: blockRemote);
      }
      // Only favor the path if the file actually exists; otherwise fall back to initialHtml/raw
      try {
        if (File(widget.initialHtmlPath!).existsSync()) {
          // Placeholder while file:// is loaded in onWebViewCreated/_reloadHtml
          // Force a light CSS for cached content to avoid black-on-black in dark mode
          final css = _baseCss(false, widget.textScale);
          final placeholder =
              '<div style="padding:16px;color:#777;font-size:13px;">Loading cached content…</div>';
          return _wrapHtml(
            _csp(blockRemote),
            '<style>$css</style>\n$placeholder',
          );
        }
      } catch (_) {}
    }
    // Fall back to full inline HTML if no file is present
    return _buildInlineHtml(blockRemote: blockRemote);
  }

  // Build the actual inline HTML we can load as a robust fallback
  String _buildInlineHtml({required bool blockRemote}) {
    // Enterprise policy: when remote images are allowed (blockRemote=false), prefer RAW HTML from the message,
    // not the pre-sanitized initialHtml, to preserve external image URLs.
    if (!blockRemote) {
      final raw = widget.mimeMessage.decodeTextHtmlPart();
      if (raw == null || raw.trim().isEmpty) {
        // When unblocked and raw is empty, fall back to provided initialHtml if present (sanitized/plain), else plain text
        if (widget.initialHtml != null &&
            widget.initialHtml!.trim().isNotEmpty) {
          final css = _baseCss(false, widget.textScale);
          return _wrapHtml(
            _csp(blockRemote),
            '<style>$css</style>\n${widget.initialHtml!}',
          );
        }
        final plain = widget.mimeMessage.decodeTextPlainPart() ?? '';
        return _wrapHtml(
          _csp(blockRemote),
          '<pre class="wb-pre">${_escapeHtml(plain)}</pre>',
        );
      }
      String html = raw;
      html = _stripDangerous(
        html,
      ); // remove scripts/objects but keep external image URLs intact
      html = _rewriteCidImages(html, widget.mimeMessage);
      final css = _baseCss(false, widget.textScale);
      return _wrapHtml(_csp(blockRemote), '<style>$css</style>\n$html');
    }

    // When blocked, favor sanitized/cached initialHtml if provided; otherwise derive from raw with blocking
    if (widget.initialHtml != null && widget.initialHtml!.trim().isNotEmpty) {
      final css = _baseCss(false, widget.textScale);
      return _wrapHtml(
        _csp(blockRemote),
        '<style>$css</style>\n${widget.initialHtml!}',
      );
    }

    final rawHtml = widget.mimeMessage.decodeTextHtmlPart();
    if (rawHtml == null || rawHtml.trim().isEmpty) {
      final plain = widget.mimeMessage.decodeTextPlainPart() ?? '';
      return _wrapHtml(
        _csp(blockRemote),
        '<pre class="wb-pre">${_escapeHtml(plain)}</pre>',
      );
    }

    String html = rawHtml;
    html = _stripDangerous(html);
    html = _rewriteCidImages(html, widget.mimeMessage);
    if (blockRemote) {
      html = _blockRemoteImages(html);
    }

    // Force light CSS to ensure readability across email themes
    final css = _baseCss(false, widget.textScale);
    return _wrapHtml(_csp(blockRemote), '<style>$css</style>\n$html');
  }

  String _csp(bool blocked) {
    final imgSrc =
        blocked
            ? "img-src 'self' data: about: cid:;"
            : "img-src 'self' data: about: cid: http: https:;";
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
      img, video, iframe { display:inline-block; max-width:100% !important; height:auto !important; width:auto !important; }
      table { max-width:100% !important; width:auto !important; table-layout:auto !important; border-collapse:collapse; }
      .wb-container table { max-width:100% !important; width:auto !important; }
      td, th { word-break: break-word; }
      pre, code { white-space:pre-wrap !important; word-break:break-word !important; }
      blockquote { border-left:4px solid $link; background:$quote; padding:8px 12px; margin:8px 0; }
      a { color:$link; text-decoration:none; }
      a:hover { text-decoration:underline; }
      .wb-pre { white-space: pre-wrap; }
      /* Signature responsiveness */
      .gmail_signature, .signature, [class*="signature"] { font-size:14px !important; line-height:1.4 !important; }
      .gmail_signature img, .signature img, [class*="signature"] img { max-width:100% !important; height:auto !important; width:auto !important; }
      .gmail_signature table, .signature table, [class*="signature"] table { width:auto !important; max-width:100% !important; table-layout:auto !important; }
    ''';
  }

  String _stripDangerous(String html) {
    try {
      html = html.replaceAll(
        RegExp(r'<script[\s\S]*?>[\s\S]*?<\/script>', caseSensitive: false),
        '',
      );
      html = html.replaceAll(
        RegExp(r'<object[\s\S]*?>[\s\S]*?<\/object>', caseSensitive: false),
        '',
      );
      html = html.replaceAll(
        RegExp(r'<embed[\s\S]*?>', caseSensitive: false),
        '',
      );
      html = html.replaceAll(
        RegExp(r'on\w+\s*=\s*"[^"]*"', caseSensitive: false),
        '',
      );
      html = html.replaceAll(
        RegExp(r"on\w+\s*=\s*'[^']*'", caseSensitive: false),
        '',
      );
      html = html.replaceAll(
        RegExp(r'href\s*=\s*"javascript:[^"]*"', caseSensitive: false),
        '',
      );
      html = html.replaceAll(
        RegExp(r"href\s*=\s*'javascript:[^']*'", caseSensitive: false),
        '',
      );
      return html;
    } catch (_) {
      return html;
    }
  }

  String _blockRemoteImages(String html) {
    const spacer =
        'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==';
    // Replace direct img src
    html = html.replaceAllMapped(
      RegExp(
        r'<img([^>]*?)src\s*=\s*\"https?:[^\"]*\"([^>]*)>',
        caseSensitive: false,
      ),
      (m) => '<img${m.group(1) ?? ''}src="$spacer"${m.group(2) ?? ''}>',
    );
    html = html.replaceAllMapped(
      RegExp(
        r"<img([^>]*?)src\s*=\s*'https?:[^']*'([^>]*)>",
        caseSensitive: false,
      ),
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
      RegExp(
        r'<img([^>]*?)(data-(?:src|original|lazy-src))\s*=\s*\"https?:[^\"]*\"',
        caseSensitive: false,
      ),
      (m) => '<img${m.group(1) ?? ''}${m.group(2)}="$spacer"',
    );
    html = html.replaceAllMapped(
      RegExp(
        r"<img([^>]*?)(data-(?:src|original|lazy-src))\s*=\s*'https?:[^']*'",
        caseSensitive: false,
      ),
      (m) => "<img${m.group(1) ?? ''}${m.group(2)}='$spacer'",
    );
    // Neutralize <source srcset> within <picture>
    html = html.replaceAllMapped(
      RegExp(
        r'<source([^>]*?)srcset\s*=\s*\"https?:[^\"]*\"',
        caseSensitive: false,
      ),
      (m) => '<source${m.group(1) ?? ''}srcset="">',
    );
    html = html.replaceAllMapped(
      RegExp(
        r"<source([^>]*?)srcset\s*=\s*'https?:[^']*'",
        caseSensitive: false,
      ),
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

  // Ensure allowRemote query param matches current policy for HTTP URLs from the local server
  String _withAllowRemoteParam(String url, {required bool allowRemote}) {
    try {
      final uri = Uri.parse(url);
      final params = Map<String, String>.from(uri.queryParameters);
      params['allowRemote'] = allowRemote ? '1' : '0';
      final newUri = uri.replace(queryParameters: params);
      return newUri.toString();
    } catch (_) {
      return url;
    }
  }
}
