import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wahda_bank/services/mime_utils.dart';
import 'package:archive/archive.dart' as z;
import 'package:xml/xml.dart' as xml;
import 'package:wahda_bank/design_system/components/app_scaffold.dart';

class AttachmentViewer extends StatefulWidget {
  const AttachmentViewer({
    super.key,
    required this.title,
    required this.mimeType,
    required this.filePath,
    this.originalBytes,
    this.skipPreprocess =
        false, // Test-only: skip preprocessing to avoid plugin init in headless CI
  });
  final String title;
  final String mimeType;
  final String filePath;
  final Uint8List? originalBytes; // Original attachment bytes for validation
  final bool skipPreprocess;

  @override
  State<AttachmentViewer> createState() => _AttachmentViewerState();
}

class _AttachmentViewerState extends State<AttachmentViewer> {
  bool _webFailed = false;
  bool _isReady = false;
  bool _isProcessing = false;
  PdfControllerPinch? _pdfController;
  Uint8List? _processedBytes;
  String? _processedContent;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.skipPreprocess) {
      // In tests, we can skip preprocessing to avoid flakiness due to plugin initializers.
      _isProcessing = false;
      return;
    }
    _preprocessAttachment();
  }

  @override
  void dispose() {
    try {
      _pdfController?.dispose();
    } catch (_) {}
    super.dispose();
  }

  /// Preprocess attachment to handle encoding issues
  Future<void> _preprocessAttachment() async {
    if (!mounted) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final file = File(widget.filePath);
      if (!await file.exists()) {
        setState(() {
          _errorMessage = 'File not found';
          _isProcessing = false;
        });
        return;
      }

      final fileBytes = await file.readAsBytes();
      final mime = MimeUtils.inferMimeType(
        widget.title,
        contentType: widget.mimeType,
      );

      // Handle different content types with proper decoding
      if (_isTextBasedContent(mime)) {
        await _preprocessTextContent(fileBytes, mime);
      } else if (_isBinaryContent(mime)) {
        await _preprocessBinaryContent(fileBytes, mime);
      } else {
        // Unknown content, try to auto-detect
        await _autoDetectAndPreprocess(fileBytes);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to process attachment: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _preprocessTextContent(Uint8List bytes, String mime) async {
    try {
      String content = utf8.decode(bytes, allowMalformed: true);

      // Check if content is base64 encoded
      if (_isLikelyBase64Content(content)) {
        try {
          final decodedBytes = base64.decode(
            content.replaceAll(RegExp(r'\s'), ''),
          );

          // Try to decode as text first
          try {
            final decodedText = utf8.decode(decodedBytes);
            content = decodedText;
          } catch (_) {
            // If text decode fails, store as binary
            _processedBytes = Uint8List.fromList(decodedBytes);
          }
        } catch (_) {
          // Base64 decode failed, use original content
        }
      }

      _processedContent = content;
    } catch (e) {
      _processedContent = 'Failed to decode text content: $e';
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _preprocessBinaryContent(Uint8List bytes, String mime) async {
    try {
      // For binary content, check if it's actually base64 text
      final asText = utf8.decode(bytes, allowMalformed: true);

      if (_isLikelyBase64Content(asText)) {
        try {
          final decodedBytes = base64.decode(
            asText.replaceAll(RegExp(r'\s'), ''),
          );

          // Validate the decoded content matches expected MIME type
          if (_validateBinaryContent(decodedBytes, mime)) {
            _processedBytes = Uint8List.fromList(decodedBytes);

            // Write processed bytes to a temporary file for viewing
            await _writeProcessedFile(decodedBytes);
          } else {
            // Decoded content doesn't match MIME type, use original
            _processedBytes = bytes;
          }
        } catch (_) {
          _processedBytes = bytes;
        }
      } else {
        _processedBytes = bytes;
      }
    } catch (e) {
      _processedBytes = bytes;
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _autoDetectAndPreprocess(Uint8List bytes) async {
    try {
      final asText = utf8.decode(bytes, allowMalformed: true);

      if (_isLikelyBase64Content(asText)) {
        try {
          final decodedBytes = base64.decode(
            asText.replaceAll(RegExp(r'\s'), ''),
          );
          final detectedMime = _detectMimeFromBytes(decodedBytes);

          if (detectedMime != null) {
            if (_isTextBasedContent(detectedMime)) {
              _processedContent = utf8.decode(
                decodedBytes,
                allowMalformed: true,
              );
            } else {
              _processedBytes = Uint8List.fromList(decodedBytes);
              await _writeProcessedFile(decodedBytes);
            }
          } else {
            _processedBytes = bytes;
          }
        } catch (_) {
          _processedBytes = bytes;
        }
      } else {
        _processedBytes = bytes;
      }
    } catch (e) {
      _processedBytes = bytes;
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _writeProcessedFile(Uint8List processedBytes) async {
    try {
      final file = File(widget.filePath);
      await file.writeAsBytes(processedBytes, flush: true);
    } catch (e) {
      // Ignore write errors, viewer will use original file
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return AppScaffold(
        appBar: AppBar(
          title: Text(widget.title, overflow: TextOverflow.ellipsis),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Processing attachment...'),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return AppScaffold(
        appBar: AppBar(
          title: Text(widget.title, overflow: TextOverflow.ellipsis),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Semantics(
                button: true,
                label: 'Retry',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 88,
                    minHeight: 44,
                  ),
                  child: ElevatedButton(
                    onPressed: () => _preprocessAttachment(),
                    child: const Text('Retry'),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final mime =
        MimeUtils.inferMimeType(
          widget.title,
          contentType: widget.mimeType,
        ).toLowerCase();
    final isImage = mime.startsWith('image/');
    final isPdf =
        mime == 'application/pdf' ||
        widget.filePath.toLowerCase().endsWith('.pdf');
    final isTextLike = _isTextBasedContent(mime);

    return AppScaffold(
      appBar: AppBar(
        title: Text(widget.title, overflow: TextOverflow.ellipsis),
        actions: [
          Semantics(
            button: true,
            label: 'Save',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: IconButton(
                tooltip: 'Save',
                icon: const Icon(Icons.download_rounded),
                onPressed: () async {
                  try {
                    await _showSaveMenu();
                  } catch (_) {}
                },
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'Share',
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: IconButton(
                tooltip: 'Share',
                icon: const Icon(Icons.ios_share),
                onPressed: () async {
                  try {
                    await Share.shareXFiles([
                      XFile(widget.filePath),
                    ], text: widget.title);
                  } catch (_) {}
                },
              ),
            ),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (isImage) {
            return _buildImageView();
          } else if (isPdf) {
            return _buildPdfView();
          } else if (_isDocx(widget.filePath)) {
            return _buildDocxView();
          } else if (_isXlsx(widget.filePath)) {
            return _buildXlsxView();
          } else if (_looksLikeOffice(widget.filePath)) {
            // Fallback placeholder for other office formats
            return _buildOfficePlaceholder(context);
          } else if (isTextLike) {
            return _buildTextView();
          } else {
            // Try webview for other formats
            return _webFailed
                ? _buildGenericPlaceholder(context)
                : _buildWebView();
          }
        },
      ),
    );
  }

  Widget _buildImageView() {
    return InteractiveViewer(
      child: Center(
        child:
            _processedBytes != null
                ? Image.memory(
                  _processedBytes!,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, st) => _buildImageError(ctx),
                )
                : Image.file(
                  File(widget.filePath),
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, err, st) => _buildImageError(ctx),
                ),
      ),
    );
  }

  Widget _buildImageError(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.broken_image,
          size: 64,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 16),
        const Text('Unable to display image'),
        const SizedBox(height: 8),
        Text(
          'Format: ${widget.mimeType}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  bool _looksLikeOffice(String path) {
    final ext = path.toLowerCase().split('.').last;
    const office = {'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'};
    return office.contains(ext);
  }

  bool _isDocx(String path) => path.toLowerCase().endsWith('.docx');
  bool _isXlsx(String path) => path.toLowerCase().endsWith('.xlsx');

  Widget _buildTextView() {
    final content = _processedContent ?? _getFileContent();
    if (content == null) {
      return _buildTextError(context);
    }

    return Column(
      children: [
        // Content info bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Icon(
                Icons.text_snippet,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                '${content.split('\n').length} lines, ${content.length} characters',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                widget.mimeType,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              content,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextError(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.text_snippet_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          const Text('Unable to display text content'),
          const SizedBox(height: 8),
          Text(
            'Format: ${widget.mimeType}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String? _getFileContent() {
    try {
      return File(widget.filePath).readAsStringSync();
    } catch (_) {
      return null;
    }
  }

  Widget _buildWebView() {
    final path = widget.filePath;
    final url = 'file://$path';

    if (_webFailed) {
      return _buildGenericPlaceholder(context);
    }

    return Stack(
      children: [
        InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri(url)),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: false,
            incognito: true,
            clearCache: true,
            clearSessionCache: true,
            allowFileAccessFromFileURLs: true,
            allowUniversalAccessFromFileURLs: false,
            mediaPlaybackRequiresUserGesture: true,
          ),
          onLoadStop: (controller, uri) {
            setState(() => _isReady = true);
          },
          onReceivedError: (controller, req, error) {
            setState(() {
              _webFailed = true;
              _isReady = true;
            });
          },
        ),
        if (!_isReady)
          const Positioned.fill(
            child: Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPdfView() {
    _pdfController ??= PdfControllerPinch(
      document: PdfDocument.openFile(widget.filePath),
    );

    return Stack(
      children: [
        PdfViewPinch(
          controller: _pdfController!,
          onDocumentLoaded: (_) => setState(() => _isReady = true),
          onDocumentError: (err) {
            // Try a fallback path: load via bytes instead of file path (helps with some iOS edge-cases)
            // ignore: avoid_print
            try {
              print('PDFX error for ${widget.filePath}: $err');
            } catch (_) {}
            _tryOpenPdfViaData();
          },
        ),
        if (!_isReady)
          const Positioned.fill(
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        if (_webFailed) Positioned.fill(child: _noPreviewPlaceholder(context)),
      ],
    );
  }

  Future<void> _tryOpenPdfViaData() async {
    try {
      setState(() {
        _isReady = false;
        _webFailed = false;
      });
      final f = File(widget.filePath);
      if (!await f.exists()) {
        setState(() {
          _webFailed = true;
          _isReady = true;
        });
        return;
      }
      Uint8List bytes = await f.readAsBytes();
      // Basic PDF signature check: %PDF-
      bool isPdf =
          bytes.length >= 5 &&
          bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46 &&
          bytes[4] == 0x2D;
      if (!isPdf) {
        // Some servers send base64 text or data URIs in the file; try to decode robustly
        try {
          final asText = await f.readAsString();
          final b64 = _tryDecodeBase64ToBytes(asText);
          if (b64 != null &&
              b64.length >= 5 &&
              b64[0] == 0x25 &&
              b64[1] == 0x50 &&
              b64[2] == 0x44 &&
              b64[3] == 0x46 &&
              b64[4] == 0x2D) {
            bytes = b64;
            isPdf = true;
            // Persist normalized PDF bytes to disk so subsequent opens succeed
            try {
              await f.writeAsBytes(bytes, flush: true);
            } catch (_) {}
          }
        } catch (_) {}
      }
      if (!isPdf) {
        setState(() {
          _webFailed = true;
          _isReady = true;
        });
        return;
      }
      // Swap controller
      try {
        _pdfController?.dispose();
      } catch (_) {}
      _pdfController = PdfControllerPinch(
        document: PdfDocument.openData(bytes),
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted)
        setState(() {
          _webFailed = true;
          _isReady = true;
        });
    }
  }

  Future<void> _showSaveMenu() async {
    final mime =
        MimeUtils.inferMimeType(
          widget.title,
          contentType: widget.mimeType,
        ).toLowerCase();
    final isImage = mime.startsWith('image/');
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.folder_copy_rounded),
                title: const Text('Save to Files'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await _saveToFiles();
                },
              ),
              if (isImage)
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: const Text('Save to Photos'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _saveToPhotos();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveToFiles() async {
    try {
      final src = File(widget.filePath);
      if (!await src.exists()) return;
      final name =
          widget.title.isNotEmpty ? widget.title : src.uri.pathSegments.last;
      // Copy to app Documents (visible in Files app under On My iPhone / app folder)
      final dir = await getApplicationDocumentsDirectory();
      final dst = File('${dir.path}/$name');
      await dst.writeAsBytes(await src.readAsBytes(), flush: true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved to Files: ${dst.path.split('/').take(6).join('/')}/…/${dst.uri.pathSegments.last}',
          ),
        ),
      );
      // Offer native Save to Files / share sheet as well
      try {
        // ignore: deprecated_member_use
        await Share.shareXFiles([XFile(dst.path)], text: widget.title);
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<void> _saveToPhotos() async {
    try {
      final src = File(widget.filePath);
      if (!await src.exists()) return;
      final mime =
          MimeUtils.inferMimeType(
            widget.title,
            contentType: widget.mimeType,
          ).toLowerCase();
      if (!mime.startsWith('image/')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only images can be saved to Photos')),
        );
        return;
      }
      // Use share sheet approach to allow user to save to Photos if direct save is unavailable
      try {
        // iOS/Android: share sheet includes Save Image to Photos
        // ignore: deprecated_member_use
        await Share.shareXFiles([XFile(src.path)], text: widget.title);
      } catch (_) {
        // fallback: copy to Documents and notify
        await _saveToFiles();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save to Photos failed: $e')));
    }
  }

  Widget _buildOfficePlaceholder(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description,
            size: 80,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Office Document',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            widget.title,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.mimeType,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Use Share or Save to open in\ncompatible applications',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDocxView() {
    return FutureBuilder<String>(
      future: _extractDocxText(widget.filePath),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final text = snap.data;
        if (text == null || text.trim().isEmpty) {
          return _buildOfficePlaceholder(context);
        }
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  const Icon(Icons.description, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'DOCX preview (text-only)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(text),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildXlsxView() {
    return FutureBuilder<List<List<String>>>(
      future: _extractXlsxTable(widget.filePath, maxRows: 200, maxCols: 30),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snap.data;
        if (rows == null || rows.isEmpty) {
          return _buildOfficePlaceholder(context);
        }
        // Build a simple table view
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  const Icon(Icons.table_chart, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'XLSX preview (first ${rows.length} rows)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width,
                  ),
                  child: SingleChildScrollView(
                    child: Table(
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      columnWidths: {
                        for (
                          int i = 0;
                          i < (rows.isNotEmpty ? rows.first.length : 0);
                          i++
                        )
                          i: const IntrinsicColumnWidth(),
                      },
                      border: TableBorder.all(
                        color: Theme.of(context).dividerColor,
                      ),
                      children: [
                        for (final row in rows)
                          TableRow(
                            children: [
                              for (final cell in row)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(cell, softWrap: true),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String> _extractDocxText(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final arch = z.ZipDecoder().decodeBytes(bytes, verify: false);
      z.ArchiveFile? entry;
      for (final f in arch.files) {
        if (f.name == 'word/document.xml') {
          entry = f;
          break;
        }
      }
      if (entry == null) return '';
      final docXml = utf8.decode(
        entry.content as List<int>,
        allowMalformed: true,
      );
      final doc = xml.XmlDocument.parse(docXml);
      final buffer = StringBuffer();
      // Paragraphs are w:p, text nodes are w:t, line breaks w:br
      for (final p in doc.findAllElements('w:p')) {
        for (final t in p.findAllElements('w:t')) {
          buffer.write(t.innerText);
        }
        buffer.writeln();
      }
      return buffer.toString();
    } catch (_) {
      return '';
    }
  }

  Future<List<List<String>>> _extractXlsxTable(
    String path, {
    int maxRows = 200,
    int maxCols = 30,
  }) async {
    try {
      final bytes = await File(path).readAsBytes();
      final arch = z.ZipDecoder().decodeBytes(bytes, verify: false);
      // Shared strings (optional)
      z.ArchiveFile? sstEntry;
      for (final f in arch.files) {
        if (f.name == 'xl/sharedStrings.xml') {
          sstEntry = f;
          break;
        }
      }
      List<String> shared = [];
      if (sstEntry != null) {
        final sstXml = utf8.decode(
          sstEntry.content as List<int>,
          allowMalformed: true,
        );
        final sstDoc = xml.XmlDocument.parse(sstXml);
        shared = sstDoc.findAllElements('si').map((si) => si.text).toList();
      }
      // First worksheet
      z.ArchiveFile? sheet;
      for (final f in arch.files) {
        if (f.name == 'xl/worksheets/sheet1.xml') {
          sheet = f;
          break;
        }
      }
      if (sheet == null) {
        for (final f in arch.files) {
          if (f.name.startsWith('xl/worksheets/sheet') &&
              f.name.endsWith('.xml')) {
            sheet = f;
            break;
          }
        }
      }
      if (sheet == null) return [];
      final wsXml = utf8.decode(
        sheet.content as List<int>,
        allowMalformed: true,
      );
      final wsDoc = xml.XmlDocument.parse(wsXml);
      // Parse rows and cells
      final rows = <List<String>>[];
      for (final row in wsDoc.findAllElements('row')) {
        if (rows.length >= maxRows) break;
        final cells = <String>[];
        int colCount = 0;
        for (final c in row.findAllElements('c')) {
          if (colCount >= maxCols) break;
          final tAttr = c.getAttribute('t');
          final v = c.getElement('v')?.text ?? '';
          if (tAttr == 's') {
            final idx = int.tryParse(v) ?? -1;
            cells.add(idx >= 0 && idx < shared.length ? shared[idx] : '');
          } else {
            cells.add(v);
          }
          colCount++;
        }
        rows.add(cells);
      }
      // Ensure equal length rows
      final maxLen = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
      for (final r in rows) {
        while (r.length < maxLen) {
          r.add('');
        }
      }
      return rows;
    } catch (_) {
      return [];
    }
  }

  Widget _buildGenericPlaceholder(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_drive_file,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 24),
          Text(
            'Preview Not Available',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            widget.title,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.mimeType,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Use Share or Save to access the file',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helpers to detect and decode base64 text content
  bool _looksLikeBase64(String s) {
    final t = s.replaceAll(RegExp(r'\s'), '');
    if (t.isEmpty || t.length % 4 != 0) return false;
    // Must be only base64 charset
    if (!RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(t)) return false;
    return true;
  }

  Uint8List? _tryDecodeBase64ToBytes(String s) {
    try {
      // 1) Direct full-string base64
      if (_looksLikeBase64(s)) {
        return Uint8List.fromList(
          base64.decode(s.replaceAll(RegExp(r'\s'), '')),
        );
      }
      final lower = s.toLowerCase();
      // 2) data URI pattern: data:application/pdf;base64,<payload>
      final idx = lower.indexOf('base64,');
      if (idx != -1) {
        final payload = s.substring(idx + 'base64,'.length);
        final cleaned = payload.replaceAll(RegExp(r'[^A-Za-z0-9+/=]'), '');
        if (cleaned.isNotEmpty && _looksLikeBase64(cleaned)) {
          return Uint8List.fromList(base64.decode(cleaned));
        }
      }
      // 3) Search for a likely PDF base64 start token 'JVBERi0' and decode contiguous base64 chars
      final jvberIdx = s.indexOf('JVBERi0');
      if (jvberIdx != -1) {
        int end = jvberIdx;
        while (end < s.length && RegExp(r'[A-Za-z0-9+/=]').hasMatch(s[end])) {
          end++;
        }
        final segment = s
            .substring(jvberIdx, end)
            .replaceAll(RegExp(r'\s'), '');
        if (_looksLikeBase64(segment)) {
          return Uint8List.fromList(base64.decode(segment));
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Content type detection helpers
  bool _isTextBasedContent(String mime) {
    final m = mime.toLowerCase();
    return m.startsWith('text/') ||
        m == 'application/json' ||
        m == 'application/xml' ||
        m.contains('csv') ||
        m.contains('javascript') ||
        m.contains('html');
  }

  bool _isBinaryContent(String mime) {
    final m = mime.toLowerCase();
    return m.startsWith('image/') ||
        m.startsWith('video/') ||
        m.startsWith('audio/') ||
        m == 'application/pdf' ||
        m.contains('zip') ||
        m.contains('office') ||
        m.contains('document') ||
        m.contains('spreadsheet') ||
        m.contains('presentation');
  }

  bool _isLikelyBase64Content(String content) {
    // Check if content looks like base64
    if (content.length < 20) return false;

    // Remove whitespace and check length
    final cleaned = content.replaceAll(RegExp(r'\s'), '');
    if (cleaned.length % 4 != 0) return false;

    // Check character set
    if (!RegExp(r'^[A-Za-z0-9+/]*={0,2}$').hasMatch(cleaned)) return false;

    // Additional heuristic: base64 encoded content usually has high entropy
    final uniqueChars = Set.from(cleaned.split(''));
    return uniqueChars.length >
        10; // Base64 should have good character distribution
  }

  bool _validateBinaryContent(Uint8List bytes, String expectedMime) {
    if (bytes.length < 4) return false;

    final mime = expectedMime.toLowerCase();

    // PDF validation
    if (mime == 'application/pdf') {
      return bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46;
    }

    // Image validations
    if (mime == 'image/jpeg') {
      return bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
    }

    if (mime == 'image/png') {
      return bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47;
    }

    if (mime == 'image/gif') {
      return bytes[0] == 0x47 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x38;
    }

    // ZIP-based formats (Office documents)
    if (mime.contains('zip') ||
        mime.contains('office') ||
        mime.contains('document')) {
      return bytes[0] == 0x50 && bytes[1] == 0x4B; // PK signature
    }

    // If we can't validate, assume it's correct
    return true;
  }

  String? _detectMimeFromBytes(Uint8List bytes) {
    if (bytes.length < 4) return null;

    // PDF
    if (bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      return 'application/pdf';
    }

    // JPEG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }

    // PNG
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }

    // GIF
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return 'image/gif';
    }

    // ZIP (and Office formats)
    if (bytes[0] == 0x50 && bytes[1] == 0x4B) {
      return 'application/zip';
    }

    // Try to detect text content
    try {
      final text = utf8.decode(bytes, allowMalformed: false);
      // If decode succeeds without malformation, likely text
      if (text.isNotEmpty) {
        return 'text/plain';
      }
    } catch (_) {}

    return null;
  }

  Widget _noPreviewPlaceholder(BuildContext context) {
    return _buildGenericPlaceholder(context);
  }
}
