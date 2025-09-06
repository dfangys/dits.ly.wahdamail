import 'dart:io';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:open_app_file/open_app_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wahda_bank/features/messaging/presentation/screens/message_detail/attachment_viewer.dart';
import 'package:wahda_bank/features/messaging/application/message_content_usecase.dart';
import 'package:wahda_bank/shared/di/injection.dart';
import 'package:wahda_bank/services/message_content_store.dart';
import 'package:wahda_bank/services/thumbnail_service.dart';
import 'package:wahda_bank/services/attachment_fetcher.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/app/api/mailbox_controller_api.dart';
import 'package:wahda_bank/services/internet_service.dart';

class AttachmentCarousel extends StatefulWidget {
  const AttachmentCarousel({
    super.key,
    required this.message,
    required this.mailbox,
    this.includeInline = false,
    this.offlineOnly = false,
    this.showHeader = true,
    this.maxDownloadBytesPerAttachment = 10 * 1024 * 1024, // 10 MB
    this.maxDownloadTotalBytes = 50 * 1024 * 1024, // 50 MB
  });
  final MimeMessage message;
  final Mailbox mailbox;
  final bool includeInline; // include inline (cid) parts in the carousel
  final bool offlineOnly; // show only cached (offline) attachments
  final bool showHeader; // show header row with actions
  final int maxDownloadBytesPerAttachment;
  final int maxDownloadTotalBytes;

  @override
  State<AttachmentCarousel> createState() => _AttachmentCarouselState();
}

class _AttachmentCarouselState extends State<AttachmentCarousel> {
  final List<_AttachmentItem> _items = [];
  bool _isLoading = true;
  bool _isBulkDownloading = false;
  ValueNotifier<int>? _metaNotifier; // reacts to content updates
  final int _thumbPreviewMaxBytes = 1024 * 1024; // 1 MB small previews
  final Set<String> _thumbFetching = <String>{};

  MessageContentUseCase? _content;

  @override
  void initState() {
    super.initState();
    _content = getIt.isRegistered<MessageContentUseCase>()
        ? getIt<MessageContentUseCase>()
        : null;
    try {
      final ctrl = Get.find<MailBoxController>();
      _metaNotifier = ctrl.getMessageMetaNotifier(
        widget.mailbox,
        widget.message,
      );
      _metaNotifier?.addListener(_loadAttachments);
    } catch (_) {}
    _loadAttachments();
  }

  @override
  void didUpdateWidget(covariant AttachmentCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message ||
        oldWidget.mailbox != widget.mailbox ||
        oldWidget.includeInline != widget.includeInline ||
        oldWidget.offlineOnly != widget.offlineOnly) {
      try {
        _metaNotifier?.removeListener(_loadAttachments);
      } catch (_) {}
      try {
        final ctrl = Get.find<MailBoxController>();
        _metaNotifier = ctrl.getMessageMetaNotifier(
          widget.mailbox,
          widget.message,
        );
        _metaNotifier?.addListener(_loadAttachments);
      } catch (_) {}
      _loadAttachments();
    }
  }

  @override
  void dispose() {
    try {
      _metaNotifier?.removeListener(_loadAttachments);
    } catch (_) {}
    _metaNotifier = null;
    super.dispose();
  }

  Future<void> _loadAttachments() async {
    try {
      setState(() => _isLoading = true);
      _items.clear();
      final seenNM = <String>{}; // keys by name|mime|size
      final seenNameMime = <String>{}; // keys by name|mime
      final seenOff = <String>{}; // keys by name|mime|size|filePath
      final Map<String, int> indexByNM = {};
      final Map<String, int> indexByNameMime = {};

      // Build a map of name|mime|size -> fetchId from current message
      Map<String, String> mimeFetchByKey = {};
      Map<String, String> mimeFetchByNameMime = {};
      List<ContentInfo> mimeCombined = const [];
      try {
        final mimeInfosBase = widget.message.findContentInfo(
          disposition: ContentDisposition.attachment,
        );
        final inlineInfosBase =
            widget.includeInline
                ? widget.message.findContentInfo(
                  disposition: ContentDisposition.inline,
                )
                : const <ContentInfo>[];
        mimeCombined =
            <ContentInfo>[]
              ..addAll(mimeInfosBase)
              ..addAll(inlineInfosBase);
        for (final ci in mimeCombined) {
          final name = (ci.fileName ?? '').toLowerCase();
          final mime =
              ci.contentType?.mediaType.toString() ??
              'application/octet-stream';
          final size = ci.size ?? 0;
          final keyNM = '$name|$mime|$size';
          final keyNameMime = '$name|$mime';
          mimeFetchByKey.putIfAbsent(keyNM, () => ci.fetchId);
          mimeFetchByNameMime.putIfAbsent(keyNameMime, () => ci.fetchId);
        }
      } catch (_) {}

      // On-demand metadata fetch if message has no ContentInfo yet and we're online
      if (!widget.offlineOnly && mimeCombined.isEmpty) {
        try {
          final online =
              Get.isRegistered<InternetService>()
                  ? InternetService.instance.connected
                  : true;
          if (online) {
          final content = _content ?? getIt<MessageContentUseCase>();
          if (!content.client.isConnected) {
              try {
                await content.connect().timeout(
                  const Duration(seconds: 12),
                );
              } catch (_) {}
            }
            if (content.client.selectedMailbox?.encodedPath !=
                widget.mailbox.encodedPath) {
              try {
                await content.client
                    .selectMailbox(widget.mailbox)
                    .timeout(const Duration(seconds: 10));
              } catch (_) {}
            }
            final seq = MessageSequence.fromMessage(widget.message);
            final fetched = await (_content ?? getIt<MessageContentUseCase>())
                .client
                .fetchMessageSequence(
                  seq,
                  fetchPreference: FetchPreference.fullWhenWithinSize,
                )
                .timeout(
                  const Duration(seconds: 20),
                  onTimeout: () => <MimeMessage>[],
                );
            if (fetched.isNotEmpty) {
              final full = fetched.first;
              final attach = full.findContentInfo(
                disposition: ContentDisposition.attachment,
              );
              final inline =
                  widget.includeInline
                      ? full.findContentInfo(
                        disposition: ContentDisposition.inline,
                      )
                      : const <ContentInfo>[];
              mimeCombined =
                  <ContentInfo>[]
                    ..addAll(attach)
                    ..addAll(inline);
              mimeFetchByKey.clear();
              for (final ci in mimeCombined) {
                final name = (ci.fileName ?? '').toLowerCase();
                final mime =
                    ci.contentType?.mediaType.toString() ??
                    'application/octet-stream';
                final size = ci.size ?? 0;
                final keyNM = '$name|$mime|$size';
                mimeFetchByKey.putIfAbsent(keyNM, () => ci.fetchId);
              }
            }
          }
        } catch (_) {}
      }

      // Load offline cached attachments first (reliable path + thumbnails)
      try {
        if (widget.message.uid != null) {
          CachedMessageContent? cached = await MessageContentStore.instance
              .getContent(
                accountEmail: (_content ?? getIt<MessageContentUseCase>()).accountEmail,
                mailboxPath:
                    widget.mailbox.encodedPath.isNotEmpty
                        ? widget.mailbox.encodedPath
                        : widget.mailbox.path,
                uidValidity: widget.mailbox.uidValidity ?? 0,
                uid: widget.message.uid!,
              );
          // Fallback for hot-restart or UIDVALIDITY mismatch
          if (cached == null || cached.attachments.isEmpty) {
            try {
              cached = await MessageContentStore.instance
                  .getContentAnyUidValidity(
                    accountEmail: (_content ?? getIt<MessageContentUseCase>()).accountEmail,
                    mailboxPath:
                        widget.mailbox.encodedPath.isNotEmpty
                            ? widget.mailbox.encodedPath
                            : widget.mailbox.path,
                    uid: widget.message.uid!,
                  );
            } catch (_) {}
          }
          if (cached != null && cached.attachments.isNotEmpty) {
            for (final a in cached.attachments) {
              if (!widget.includeInline && a.isInline) continue;
              final nameLower = a.fileName.toLowerCase();
              final mime = a.mimeType;
              final size = a.sizeBytes;
              final keyNM = '$nameLower|$mime|$size';
              final offKey = '$keyNM|${a.filePath}';
              if (seenOff.add(offKey)) {
                var guessedFetch = mimeFetchByKey[keyNM];
                if (guessedFetch == null || guessedFetch.isEmpty) {
                  // Fallback to name+mime only when server didn't provide size
                  guessedFetch = mimeFetchByNameMime['$nameLower|$mime'];
                }
                final identityKey =
                    (guessedFetch != null && guessedFetch.isNotEmpty)
                        ? 'fid:$guessedFetch'
                        : 'nm:$offKey';
                final newItem = _AttachmentItem(
                  identityKey: identityKey,
                  name: a.fileName,
                  mimeType: a.mimeType,
                  size: a.sizeBytes,
                  filePath: a.filePath,
                  isImage: _looksLikeImage(a.fileName, a.mimeType),
                  fetchId: guessedFetch,
                  contentId: a.contentId,
                );
                _items.add(newItem);
                // Mark name/mime based keys as seen so MIME entries don’t duplicate if size mismatches
                seenNM.add(keyNM);
                seenNameMime.add('$nameLower|$mime');
                indexByNM.putIfAbsent(keyNM, () => _items.length - 1);
                indexByNameMime.putIfAbsent(
                  '$nameLower|$mime',
                  () => _items.length - 1,
                );
              }
            }
          }
        }
      } catch (_) {}

      // Also include MIME attachments present on the message
      if (!widget.offlineOnly) {
        try {
          for (final ci in mimeCombined) {
            final nameLower = (ci.fileName ?? '').toLowerCase();
            final mime =
                ci.contentType?.mediaType.toString() ??
                'application/octet-stream';
            final size = ci.size ?? 0;
            final keyNM = '$nameLower|$mime|$size';
            if (seenNM.contains(keyNM) ||
                seenNameMime.contains('$nameLower|$mime')) {
              // Enrich existing item with fetchId when offline entry exists (match exact or fallback)
              int idx = indexByNM[keyNM] ?? -1;
              if (idx == -1) idx = indexByNameMime['$nameLower|$mime'] ?? -1;
              if (idx != -1 &&
                  (_items[idx].fetchId == null ||
                      _items[idx].fetchId!.isEmpty)) {
                final identityKey = 'fid:${ci.fetchId}';
                _items[idx] = _items[idx].copyWith(
                  identityKey: identityKey,
                  fetchId: ci.fetchId,
                );
              }
              continue;
            }

            final displayName = ci.fileName ?? 'attachment';
            final isImage = _looksLikeImage(displayName, mime);
            if (seenNM.add(keyNM)) {
              final identityKey = 'fid:${ci.fetchId}';
              _items.add(
                _AttachmentItem(
                  identityKey: identityKey,
                  name: displayName,
                  mimeType: mime,
                  size: size,
                  isImage: isImage,
                  fetchId: ci.fetchId,
                  contentId: null,
                ),
              );
              indexByNM.putIfAbsent(keyNM, () => _items.length - 1);
              seenNameMime.add('$nameLower|$mime');
              indexByNameMime.putIfAbsent(
                '$nameLower|$mime',
                () => _items.length - 1,
              );
            }
          }
        } catch (_) {}
      }

      // Kick off non-blocking thumbnail fetches for small image/PDF items lacking local data
      _kickoffThumbnailFetch();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hide loader entirely; only reveal when attachments are available
    if (_isLoading) return const SizedBox.shrink();
    if (_items.isEmpty) return const SizedBox.shrink();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: Column(
        key: ValueKey('atts-${_items.length}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHeader)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Icon(Icons.attach_file, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Attachments (${_items.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (_items.length > 1)
                    TextButton.icon(
                      onPressed:
                          _isBulkDownloading ? null : _downloadAllAttachments,
                      icon:
                          _isBulkDownloading
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Icon(Icons.download_outlined, size: 18),
                      label: const Text('Download all'),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          SizedBox(
            height: 120,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final it = _items[index];
                return _AttachmentThumb(
                  item: it,
                  onOpen: () => _openItem(it),
                  onShare: () => _shareItem(it),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openItem(_AttachmentItem it) async {
    try {
      String? path;
      // Prefer existing file, then inline bytes, then download
      if ((it.filePath ?? '').isNotEmpty && await File(it.filePath!).exists()) {
        path = it.filePath!;
      } else if (it.inlineBytes != null && it.inlineBytes!.isNotEmpty) {
        final tmp = await _saveTemp(it.inlineBytes!, it.name);
        path = tmp.path;
      } else {
        path = await _downloadItemIfNeeded(it);
      }

      if ((path ?? '').isEmpty) {
        _toast('Attachment data not available');
        return;
      }

      // Heal previously cached bad PDFs: if file doesn't start with %PDF-, attempt to re-fetch and re-save
      final isPdfByHint =
          it.mimeType.toLowerCase() == 'application/pdf' ||
          it.name.toLowerCase().endsWith('.pdf');
      if (isPdfByHint) {
        try {
          final f = File(path!);
          final b = await f.readAsBytes();
          final isPdf =
              b.length >= 5 &&
              b[0] == 0x25 &&
              b[1] == 0x50 &&
              b[2] == 0x44 &&
              b[3] == 0x46 &&
              b[4] == 0x2D;
          if (!isPdf && (it.fetchId != null && it.fetchId!.isNotEmpty)) {
            // Re-fetch using validated fetcher and re-save via store (which will normalize)
            final data = await AttachmentFetcher.fetchByFetchId(
              message: widget.message,
              fetchId: it.fetchId!,
              mailbox: widget.mailbox,
              timeout: const Duration(seconds: 20),
            );
            if (data != null && data.isNotEmpty) {
              final content = _content ?? getIt<MessageContentUseCase>();
              final newPath = await MessageContentStore.instance
                  .saveAttachmentBytes(
                    accountEmail: content.accountEmail,
                    mailboxPath:
                        widget.mailbox.encodedPath.isNotEmpty
                            ? widget.mailbox.encodedPath
                            : widget.mailbox.path,
                    uidValidity: widget.mailbox.uidValidity ?? 0,
                    uid: widget.message.uid ?? -1,
                    fileName: it.name,
                    bytes: data,
                    uniquePartId: it.fetchId,
                    contentId: it.contentId,
                    mimeType: it.mimeType,
                    size: it.size > 0 ? it.size : data.length,
                  );
              path = newPath;
            }
          }
        } catch (_) {}
      }

      final mime = it.mimeType.toLowerCase();
      final canPreviewInApp =
          mime.startsWith('image/') ||
          mime == 'application/pdf' ||
          mime.startsWith('text/') ||
          mime == 'application/json' ||
          mime.contains('csv');

      if (canPreviewInApp) {
        if (!mounted) return;
        await Get.to(
          () => AttachmentViewer(
            title: it.name,
            mimeType: it.mimeType,
            filePath: path!,
          ),
        );
        return;
      }

      // Fallback to external app for complex formats
      await OpenAppFile.open(path!);
    } catch (e) {
      _toast('Unable to open: $e');
    }
  }

  Future<void> _shareItem(_AttachmentItem it) async {
    try {
      if (it.filePath != null && it.filePath!.isNotEmpty) {
        try {
          final f = File(it.filePath!);
          if (await f.exists()) {
            // ignore: deprecated_member_use
            await Share.shareXFiles([XFile(it.filePath!)], text: it.name);
            return;
          }
        } catch (_) {}
        // File missing: re-download then share
        final path = await _downloadItemIfNeeded(it);
        if (path != null && path.isNotEmpty) {
          // ignore: deprecated_member_use
          await Share.shareXFiles([XFile(path)], text: it.name);
          return;
        }
      }
      if (it.inlineBytes != null && it.inlineBytes!.isNotEmpty) {
        final tmp = await _saveTemp(it.inlineBytes!, it.name);
        // ignore: deprecated_member_use
        await Share.shareXFiles([XFile(tmp.path)], text: it.name);
        return;
      }
      // On-demand fetch
      final path = await _downloadItemIfNeeded(it);
      if (path != null && path.isNotEmpty) {
        // ignore: deprecated_member_use
        await Share.shareXFiles([XFile(path)], text: it.name);
        return;
      }
      _toast('Attachment data not available to share');
    } catch (e) {
      _toast('Unable to share: $e');
    }
  }

  Future<File> _saveTemp(Uint8List data, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(data, flush: true);
    return file;
  }

  void _toast(String msg) {
    final ctx = Get.context;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppTheme.infoColor),
      );
    }
  }

  void _kickoffThumbnailFetch() {
    if (widget.offlineOnly) return;
    try {
      final items = List<_AttachmentItem>.from(_items);
      for (final it in items) {
        final isPdf = _looksLikePdf(it.mimeType, it.name);
        if (it.isImage) {
          if ((it.inlineBytes != null && it.inlineBytes!.isNotEmpty)) continue;
          if ((it.filePath ?? '').isNotEmpty) continue; // already on disk
          final fid = it.fetchId ?? '';
          if (fid.isEmpty) continue;
          if (it.size <= 0 || it.size > _thumbPreviewMaxBytes)
            continue; // respect preview policy
          if (!_thumbFetching.add(fid)) continue; // already in-flight
          final idKey = it.identityKey;
          () async {
            try {
              final data = await AttachmentFetcher.fetchByFetchId(
                message: widget.message,
                fetchId: fid,
                mailbox: widget.mailbox,
              );
              if (data != null &&
                  data.isNotEmpty &&
                  _isLikelyRenderableImageBytes(data)) {
                final idx = _items.indexWhere((x) => x.identityKey == idKey);
                if (idx != -1) {
                  _items[idx] = _items[idx].copyWith(inlineBytes: data);
                  if (mounted) setState(() {});
                }
              }
            } catch (_) {
            } finally {
              _thumbFetching.remove(fid);
            }
          }();
        } else if (isPdf) {
          // For PDFs, keep placeholder before full download (real render plugin not available)
          continue;
        } else {
          // Text-like small previews (CSV/JSON/TXT)
          final m = it.mimeType.toLowerCase();
          final isTextLike =
              m.startsWith('text/') || m.contains('json') || m.contains('csv');
          if (isTextLike) {
            if ((it.filePath ?? '').isNotEmpty) continue;
            if (it.size <= 0 || it.size > 128 * 1024) continue; // 128KB cap
            final fid = it.fetchId ?? '';
            if (fid.isEmpty) continue;
            if (!_thumbFetching.add(fid)) continue;
            final idKey = it.identityKey;
            () async {
              try {
                final data = await AttachmentFetcher.fetchByFetchId(
                  message: widget.message,
                  fetchId: fid,
                  mailbox: widget.mailbox,
                );
                if (data != null && data.isNotEmpty) {
                  final thumb = await ThumbnailService.instance
                      .getOrCreateTextPreviewFromBytes(
                        idKey: idKey,
                        data: data,
                        mimeType: it.mimeType,
                        maxWidth: 200,
                        maxHeight: 200,
                      );
                  if (thumb != null) {
                    final idx = _items.indexWhere(
                      (x) => x.identityKey == idKey,
                    );
                    if (idx != -1) {
                      _items[idx] = _items[idx].copyWith(
                        thumbPathOverride: thumb,
                      );
                      if (mounted) setState(() {});
                    }
                  }
                }
              } catch (_) {
              } finally {
                _thumbFetching.remove(fid);
              }
            }();
          }
        }
      }
    } catch (_) {}
  }

  Future<String?> _downloadItemIfNeeded(_AttachmentItem it) async {
    try {
      if (it.filePath != null && it.filePath!.isNotEmpty) return it.filePath;
      if (it.fetchId == null || it.fetchId!.isEmpty) return null;

      // Per-attachment size bound if known
      if (widget.maxDownloadBytesPerAttachment > 0 &&
          it.size > 0 &&
          it.size > widget.maxDownloadBytesPerAttachment) {
        _toast('Skipped ${it.name}: exceeds per-file limit');
        return null;
      }

      final content = _content ?? getIt<MessageContentUseCase>();
      // Mark fetching
      final idxStart = _items.indexOf(it);
      if (idxStart != -1) {
        _items[idxStart] = _items[idxStart].copyWith(isFetching: true);
        if (mounted) setState(() {});
      }

      // Ensure connection and mailbox
      if (!content.client.isConnected) {
        try {
          await content.connect().timeout(const Duration(seconds: 12));
        } catch (_) {}
      }
      try {
        if (content.client.selectedMailbox?.encodedPath !=
            widget.mailbox.encodedPath) {
          await content.client
              .selectMailbox(widget.mailbox)
              .timeout(const Duration(seconds: 10));
        }
      } catch (_) {}

      // Fetch the attachment bytes using the robust fetcher (handles encodings + validation)
      final data = await AttachmentFetcher.fetchByFetchId(
        message: widget.message,
        fetchId: it.fetchId!,
        mailbox: widget.mailbox,
        timeout: const Duration(seconds: 20),
      );
      if (data == null || data.isEmpty) return null;

      // Persist to offline store for reuse (collision-safe)
      final path = await MessageContentStore.instance.saveAttachmentBytes(
        accountEmail: content.accountEmail,
        mailboxPath:
            widget.mailbox.encodedPath.isNotEmpty
                ? widget.mailbox.encodedPath
                : widget.mailbox.path,
        uidValidity: widget.mailbox.uidValidity ?? 0,
        uid: widget.message.uid ?? -1,
        fileName: it.name,
        bytes: data,
        uniquePartId: it.fetchId,
        contentId: it.contentId,
        mimeType: it.mimeType,
        size: it.size > 0 ? it.size : data.length,
      );

      // Upsert into DB attachments list for offline reuse
      try {
        final store = MessageContentStore.instance;
        final cached = await store.getContent(
          accountEmail:
              (_content ?? getIt<MessageContentUseCase>()).accountEmail,
          mailboxPath:
              widget.mailbox.encodedPath.isNotEmpty
                  ? widget.mailbox.encodedPath
                  : widget.mailbox.path,
          uidValidity: widget.mailbox.uidValidity ?? 0,
          uid: widget.message.uid ?? -1,
        );
        final atts = <CachedAttachment>[];
        if (cached != null) {
          final seen = <String>{};
          for (final a in cached.attachments) {
            final cid = (a.contentId ?? '').trim().toLowerCase();
            final fk =
                '${a.fileName}|${a.sizeBytes}|${a.mimeType}'.toLowerCase();
            final k = cid.isNotEmpty ? 'cid:$cid' : fk;
            if (seen.add(k)) atts.add(a);
          }
        }
        final newCid = (it.contentId ?? '').trim().toLowerCase();
        final newFk = '${it.name}|${it.size}|${it.mimeType}'.toLowerCase();
        final newKey = newCid.isNotEmpty ? 'cid:$newCid' : newFk;
        final exists = atts.any((a) {
          final cid = (a.contentId ?? '').trim().toLowerCase();
          final fk = '${a.fileName}|${a.sizeBytes}|${a.mimeType}'.toLowerCase();
          final k = cid.isNotEmpty ? 'cid:$cid' : fk;
          return k == newKey;
        });
        if (!exists) {
          atts.add(
            CachedAttachment(
              contentId: it.contentId,
              fileName: it.name,
              mimeType: it.mimeType,
              sizeBytes: it.size > 0 ? it.size : data.length,
              isInline: widget.includeInline,
              filePath: path,
            ),
          );
        }
        await store.upsertContent(
          accountEmail:
              (_content ?? getIt<MessageContentUseCase>()).accountEmail,
          mailboxPath:
              widget.mailbox.encodedPath.isNotEmpty
                  ? widget.mailbox.encodedPath
                  : widget.mailbox.path,
          uidValidity: widget.mailbox.uidValidity ?? 0,
          uid: widget.message.uid ?? -1,
          plainText: cached?.plainText,
          htmlSanitizedBlocked: cached?.htmlSanitizedBlocked,
          htmlFilePath: cached?.htmlFilePath,
          sanitizedVersion: cached?.sanitizedVersion ?? 2,
          attachments: atts,
        );
        try {
          Get.find<MailBoxController>().bumpMessageMeta(
            widget.mailbox,
            widget.message,
          );
        } catch (_) {}
      } catch (_) {}

      // Update UI with new file path
      final idx = _items.indexWhere((x) => x.identityKey == it.identityKey);
      if (idx != -1) {
        _items[idx] = _items[idx].copyWith(filePath: path, isFetching: false);
        if (mounted) setState(() {});
      }
      return path;
    } catch (e) {
      _toast('Download failed: $e');
      return null;
    } finally {
      // Ensure fetching flag cleared if we set it
      final idx = _items.indexWhere((x) => x.identityKey == it.identityKey);
      if (idx != -1) {
        _items[idx] = _items[idx].copyWith(isFetching: false);
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _downloadAllAttachments() async {
    if (_isBulkDownloading) return;
    setState(() {
      _isBulkDownloading = true;
    });
    try {
      int totalBytes = 0;
      int downloaded = 0;
      for (final it in List<_AttachmentItem>.from(_items)) {
        if ((it.filePath ?? '').isNotEmpty) continue;
        if ((it.fetchId ?? '').isEmpty) continue;
        if (widget.maxDownloadBytesPerAttachment > 0 &&
            it.size > 0 &&
            it.size > widget.maxDownloadBytesPerAttachment) {
          continue;
        }
        final est = it.size > 0 ? it.size : 0;
        if (widget.maxDownloadTotalBytes > 0 &&
            est > 0 &&
            totalBytes + est > widget.maxDownloadTotalBytes) {
          break;
        }
        final path = await _downloadItemIfNeeded(it);
        if (path != null && path.isNotEmpty) {
          downloaded++;
          if (est == 0) {
            try {
              totalBytes += await File(path).length();
            } catch (_) {}
          } else {
            totalBytes += est;
          }
          if (widget.maxDownloadTotalBytes > 0 &&
              totalBytes >= widget.maxDownloadTotalBytes) {
            break;
          }
        }
      }
      if (downloaded > 0) {
        _toast('Downloaded $downloaded attachment(s)');
      } else {
        _toast('No attachments downloaded (already available or over limits)');
      }
    } catch (e) {
      _toast('Download all failed: $e');
    } finally {
      if (mounted)
        setState(() {
          _isBulkDownloading = false;
        });
    }
  }

  bool _looksLikeImage(String name, String mime) {
    final m = (mime).toLowerCase();
    if (m.startsWith('image/')) {
      if (m.contains('heic') || m.contains('heif') || m.contains('tif'))
        return false;
      return true;
    }
    final ext = name.toLowerCase().split('.').last;
    const imgExt = {'jpg', 'jpeg', 'png', 'gif', 'webp'};
    return imgExt.contains(ext);
  }

  bool _looksLikePdf(String mime, String name) {
    if (mime.toLowerCase() == 'application/pdf') return true;
    return name.toLowerCase().endsWith('.pdf');
  }
}

class _AttachmentItem {
  final String identityKey; // stable identity (fid:..., or nm:name|mime|size)
  final String name;
  final String mimeType;
  final int size;
  final String? filePath;
  final Uint8List? inlineBytes;
  final bool isImage;
  final String? fetchId; // for on-demand fetch when not cached
  final String? contentId; // for cid-based dedupe and reference
  final bool isFetching;
  final String? thumbPathOverride; // pre-rendered thumb path (prefetch)
  _AttachmentItem({
    required this.identityKey,
    required this.name,
    required this.mimeType,
    required this.size,
    this.filePath,
    this.inlineBytes,
    required this.isImage,
    this.fetchId,
    this.contentId,
    this.isFetching = false,
    this.thumbPathOverride,
  });

  _AttachmentItem copyWith({
    String? identityKey,
    String? name,
    String? mimeType,
    int? size,
    String? filePath,
    Uint8List? inlineBytes,
    bool? isImage,
    String? fetchId,
    String? contentId,
    bool? isFetching,
    String? thumbPathOverride,
  }) => _AttachmentItem(
    identityKey: identityKey ?? this.identityKey,
    name: name ?? this.name,
    mimeType: mimeType ?? this.mimeType,
    size: size ?? this.size,
    filePath: filePath ?? this.filePath,
    inlineBytes: inlineBytes ?? this.inlineBytes,
    isImage: isImage ?? this.isImage,
    fetchId: fetchId ?? this.fetchId,
    contentId: contentId ?? this.contentId,
    isFetching: isFetching ?? this.isFetching,
    thumbPathOverride: thumbPathOverride ?? this.thumbPathOverride,
  );
}

class _AttachmentThumb extends StatefulWidget {
  const _AttachmentThumb({
    required this.item,
    required this.onOpen,
    required this.onShare,
  });
  final _AttachmentItem item;
  final VoidCallback onOpen;
  final VoidCallback onShare;

  @override
  State<_AttachmentThumb> createState() => _AttachmentThumbState();
}

class _AttachmentThumbState extends State<_AttachmentThumb> {
  String? _thumbPath;
  bool _loadingThumb = false;

  @override
  void initState() {
    super.initState();
    _maybeGenerateThumb();
  }

  @override
  void didUpdateWidget(covariant _AttachmentThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.filePath != widget.item.filePath ||
        oldWidget.item.mimeType != widget.item.mimeType) {
      _thumbPath = null;
      _maybeGenerateThumb();
    }
  }

  Future<void> _maybeGenerateThumb() async {
    final path = widget.item.filePath;

    // If we have a local file, generate a real cached thumbnail; otherwise generate a MIME placeholder thumbnail
    if (path == null || path.isEmpty) {
      // Generate placeholder thumbnail based on MIME so a visual appears before download
      final pth = await ThumbnailService.instance
          .getOrCreateMimePlaceholderThumbnail(
            mimeType: widget.item.mimeType,
            maxWidth: 200,
            maxHeight: 200,
          );
      if (!mounted) return;
      setState(() {
        _thumbPath = pth;
        _loadingThumb = false;
      });
      return;
    }

    // Generate thumbnails for images, pdf, office, and text placeholders
    final mime = widget.item.mimeType.toLowerCase();
    final canGenerateThumb =
        mime.startsWith('image/') ||
        mime == 'application/pdf' ||
        mime.startsWith('text/') ||
        mime.contains('json') ||
        mime.contains('xml') ||
        mime.contains('word') ||
        mime.contains('excel') ||
        mime.contains('powerpoint') ||
        mime.contains('officedocument') ||
        mime.contains('spreadsheet') ||
        mime.contains('presentation');

    if (!canGenerateThumb) {
      return;
    }

    setState(() => _loadingThumb = true);
    try {
      final pth = await ThumbnailService.instance.getOrCreateThumbnail(
        filePath: path,
        mimeType: widget.item.mimeType,
        maxWidth: 200,
        maxHeight: 200,
      );
      if (!mounted) return;
      setState(() {
        _thumbPath = pth;
        _loadingThumb = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingThumb = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: widget.item.isFetching ? null : widget.onOpen,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 112,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  topRight: Radius.circular(10),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildThumb(),
                    // File ext tag bottom-left
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _ext(widget.item.name).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    // Offline/online badges
                    Positioned(right: 6, top: 6, child: _buildStatusBadge()),
                    if (widget.item.isFetching)
                      Container(
                        color: Colors.black26,
                        child: const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      maxWidth: 24,
                      maxHeight: 24,
                    ),
                    icon: const Icon(Icons.more_vert, size: 16),
                    onPressed: widget.item.isFetching ? null : widget.onShare,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumb() {
    final item = widget.item;
    final placeholder = Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Icon(
          _iconForMime(item.mimeType),
          size: 28,
          color: Colors.grey.shade600,
        ),
      ),
    );

    if (_loadingThumb) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Use precomputed override first
    final override = widget.item.thumbPathOverride;
    if (override != null && override.isNotEmpty) {
      try {
        final f = File(override);
        if (f.existsSync()) {
          return Image.file(
            f,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (ctx, err, st) => placeholder,
          );
        }
      } catch (_) {}
    }

    if (_thumbPath != null && _thumbPath!.isNotEmpty) {
      try {
        final f = File(_thumbPath!);
        if (f.existsSync()) {
          return Image.file(
            f,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (ctx, err, st) => placeholder,
          );
        }
      } catch (_) {}
    }

    if (item.isImage) {
      if (item.filePath != null && item.filePath!.isNotEmpty) {
        try {
          final f = File(item.filePath!);
          final exists = f.existsSync();
          final size = exists ? f.statSync().size : 0;
          if (exists && size > 0) {
            return Image.file(
              f,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (ctx, err, st) => placeholder,
            );
          }
        } catch (_) {}
      } else if (item.inlineBytes != null && item.inlineBytes!.isNotEmpty) {
        if (_isLikelyRenderableImageBytes(item.inlineBytes!)) {
          return Image.memory(
            item.inlineBytes!,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (ctx, err, st) => placeholder,
          );
        }
      }
    }

    return placeholder;
  }

  IconData _iconForMime(String mimeType) {
    final m = mimeType.toLowerCase();
    if (m.startsWith('image/')) return Icons.image;
    if (m == 'application/pdf') return Icons.picture_as_pdf;
    if (m.contains('zip') || m.contains('compressed')) return Icons.archive;
    if (m.contains('audio')) return Icons.audiotrack;
    if (m.contains('video')) return Icons.videocam;
    if (m.contains('wordprocessingml') || m.contains('msword'))
      return Icons.description; // Word
    if (m.contains('spreadsheetml') || m.contains('excel'))
      return Icons.table_chart; // Excel
    if (m.contains('presentationml') || m.contains('powerpoint'))
      return Icons.slideshow; // PowerPoint
    if (m.contains('officedocument')) return Icons.description;
    return Icons.insert_drive_file;
  }

  String _ext(String name) {
    final idx = name.lastIndexOf('.');
    if (idx <= 0 || idx == name.length - 1) return '';
    return name.substring(idx + 1);
  }

  Widget _buildStatusBadge() {
    try {
      // Online/offline badge + cached indicator
      final hasFile = (widget.item.filePath ?? '').isNotEmpty;
      final isOffline =
          !(Get.isRegistered<InternetService>()
              ? InternetService.instance.connected
              : true);
      if (hasFile) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white70,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: Icon(
              Icons.cloud_done_rounded,
              size: 16,
              color: Colors.green,
            ),
          ),
        );
      }
      if (isOffline) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white70,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: Icon(Icons.wifi_off_rounded, size: 16, color: Colors.red),
          ),
        );
      }
    } catch (_) {}
    return const SizedBox.shrink();
  }
}

// Lightweight image header sniffing for thumbnail safety
bool _isLikelyRenderableImageBytes(Uint8List bytes) {
  if (bytes.length < 12) return false;
  // JPEG
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) return true;
  // PNG
  const pngSig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  bool pngMatch = true;
  for (int i = 0; i < pngSig.length; i++) {
    if (bytes[i] != pngSig[i]) {
      pngMatch = false;
      break;
    }
  }
  if (pngMatch) return true;
  // GIF
  if (bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38)
    return true;
  // WEBP: 'RIFF' .... 'WEBP'
  if (bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50)
    return true;
  return false;
}
