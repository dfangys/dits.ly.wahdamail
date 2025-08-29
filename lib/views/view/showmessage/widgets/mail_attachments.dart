import 'dart:developer';
import 'dart:io';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:open_app_file/open_app_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../services/mail_service.dart';
import '../../../../services/email_cache_service.dart';
import '../../../../services/message_content_store.dart';
import '../../../../services/html_enhancer.dart';
import '../../../../services/internet_service.dart';
import '../../../../services/attachment_fetcher.dart';
import '../../../../utills/theme/app_theme.dart';
import '../../../../widgets/enhanced_attachment_viewer.dart';
import '../../../../widgets/enterprise_message_viewer.dart';

// Backoff map to avoid repeatedly attempting attachment refetch for the same UID within a short window
final Map<int, DateTime> _attachmentRefetchBackoff = <int, DateTime>{};

class MailAttachments extends StatelessWidget {
  const MailAttachments({super.key, required this.message, this.mailbox, this.showAttachmentsList = true, this.showBodyViewer = true});
  final MimeMessage message;
  final Mailbox? mailbox;
  final bool showAttachmentsList;
  final bool showBodyViewer;

  Future<MimeMessage> _fetchMessageContent() async {
    try {
      if (kDebugMode) {
        print('DEBUG: Fetching message content for UID: ${message.uid}');
        print('DEBUG: Message has envelope: ${message.envelope != null}');
        print('DEBUG: Message subject: ${message.decodeSubject()}');
        print('DEBUG: Message date: ${message.decodeDate()}');
      }
      
      // Initialize cache services
      await EmailCacheService.instance.initialize();
      
      // Get mail service instance
      final mailService = MailService.instance;

      // Prepare cache context and purge invalid UIDVALIDITY rows
      final accountEmail = mailService.account.email;
      final mailboxPath = mailbox?.encodedPath ?? mailbox?.path ?? 'INBOX';
      final uidValidity = mailbox?.uidValidity ?? 0;
      try {
        await MessageContentStore.instance.purgeInvalidUidValidity(
          accountEmail: accountEmail,
          mailboxPath: mailboxPath,
          currentUidValidity: uidValidity,
        );
      } catch (_) {}

      // FAST-PATH: If persisted cached body exists (regardless of connectivity), return immediately for instant render
      try {
        if (message.uid != null) {
          final cachedPersisted = await MessageContentStore.instance.getContent(
            accountEmail: accountEmail,
            mailboxPath: mailboxPath,
            uidValidity: uidValidity,
            uid: message.uid!,
          );
          final hasBody = cachedPersisted != null && (
            (cachedPersisted.htmlSanitizedBlocked?.isNotEmpty ?? false) ||
            (cachedPersisted.htmlFilePath?.isNotEmpty ?? false) ||
            (cachedPersisted.plainText?.isNotEmpty ?? false)
          );
          if (hasBody) {
            if (kDebugMode) {
              print('Cache-first: serving persisted cached content for UID ${message.uid} (online or offline)');
            }
            // If we have a reconstructed cached MimeMessage, prefer it; otherwise return original
            final cachedMsg = await EmailCacheService.instance.getCachedEmail(message.uid!);
            return cachedMsg ?? message;
          }
        }
      } catch (_) {}

      // If offline and persisted cached body exists, avoid any network fetches
      try {
        final offline = !InternetService.instance.connected;
        if (offline && message.uid != null) {
          final cachedOffline = await MessageContentStore.instance.getContent(
            accountEmail: accountEmail,
            mailboxPath: mailboxPath,
            uidValidity: uidValidity,
            uid: message.uid!,
          );
          final hasBody = cachedOffline != null && ((cachedOffline.htmlSanitizedBlocked?.isNotEmpty ?? false) || (cachedOffline.plainText?.isNotEmpty ?? false));
          if (hasBody) {
            if (kDebugMode) {
              print('Offline: using persisted cached content for UID ${message.uid} without network fetch');
            }
            final cachedMessage = await EmailCacheService.instance.getCachedEmail(message.uid!);
            return cachedMessage ?? message;
          }
        }
      } catch (_) {}

      // PERFORMANCE OPTIMIZATION: Check cache first, but ensure attachments are present
      if (message.uid != null) {
        final cachedMessage = await EmailCacheService.instance.getCachedEmail(message.uid!);
        if (cachedMessage != null) {
          if (kDebugMode) {
            print('Using cached message content for UID ${message.uid}');
          }

          // If the cached message lacks attachment parts, fetch full contents to restore them
          bool hasAnyContentInfo = false;
          try {
            hasAnyContentInfo = cachedMessage.findContentInfo().isNotEmpty;
          } catch (_) {
            hasAnyContentInfo = false;
          }

          if (!hasAnyContentInfo) {
            // If offline, do not refetch; rely on offline cache and persisted attachments
            if (!InternetService.instance.connected) {
              if (kDebugMode) {
                print('Offline: skipping refetch for UID ${message.uid}, using cached content');
              }
              return cachedMessage;
            }

            // Backoff: avoid repeated refetch attempts for the same UID within 2 minutes
            final uid = message.uid;
            if (uid != null) {
              final lastTried = _attachmentRefetchBackoff[uid];
              if (lastTried != null && DateTime.now().difference(lastTried) < const Duration(minutes: 2)) {
                if (kDebugMode) {
                  print('Skipping attachment refetch for UID $uid due to recent attempt');
                }
                return cachedMessage;
              }
              _attachmentRefetchBackoff[uid] = DateTime.now();
            }

            if (kDebugMode) {
              print('Cached message UID ${message.uid} has no attachment parts; refetching full contents (with timeout/retries)...');
            }
            // Ensure we're connected
            int connectionRetries = 3;
            while (!mailService.client.isConnected && connectionRetries > 0) {
              try {
                await mailService.connect().timeout(const Duration(seconds: 10));
                break;
              } catch (e) {
                connectionRetries--;
                if (connectionRetries == 0) break;
                await Future.delayed(const Duration(seconds: 1));
              }
            }

            // Ensure correct mailbox is selected
            if (mailbox != null) {
              final currentMailbox = mailService.client.selectedMailbox;
              if (currentMailbox == null || currentMailbox.path != mailbox!.path) {
                if (kDebugMode) {
                  print('Selecting mailbox: ${mailbox!.path} (current: ${currentMailbox?.path})');
                }
                try {
                  await mailService.client.selectMailbox(mailbox!).timeout(const Duration(seconds: 8));
                } catch (e) {
                  if (kDebugMode) {
                    print('Mailbox selection failed before refetch: $e');
                  }
                }
                await Future.delayed(const Duration(milliseconds: 100));
              }
            }

            // Retry refetch with timeout
            int fetchRetries = 2;
            while (fetchRetries > 0) {
              try {
                final refreshed = await mailService.client
                    .fetchMessageContents(message)
                    .timeout(const Duration(seconds: 15));

                // Persist to lightweight cache
                if (refreshed.uid != null) {
                  try { await EmailCacheService.instance.cacheEmail(refreshed); } catch (_) {}
                }

                // Persist offline body + small attachments to SQLite for reliable reuse
                try {
                  final accountEmail = mailService.account.email;
                  final mailboxPath = mailbox?.encodedPath ?? mailbox?.path ?? 'INBOX';
                  final uidValidity = mailbox?.uidValidity ?? 0;

                  String? rawHtml = refreshed.decodeTextHtmlPart();
                  String? plain = refreshed.decodeTextPlainPart();
                  String? sanitizedHtml;
                  if (rawHtml != null && rawHtml.trim().isNotEmpty) {
                    String preprocessed = rawHtml;
                    if (rawHtml.length > 100 * 1024) {
                      try { preprocessed = await MessageContentStore.sanitizeHtmlInIsolate(rawHtml); } catch (_) {}
                    }
                    final enhanced = HtmlEnhancer.enhanceEmailHtml(
                      message: refreshed,
                      rawHtml: preprocessed,
                      darkMode: Theme.of(Get.context!).brightness == Brightness.dark,
                      blockRemoteImages: true,
                      deviceWidthPx: 1024.0,
                    );
                    sanitizedHtml = enhanced.html;
                  }

                  // Save small attachments
                  final infos = refreshed.findContentInfo();
                  final List<CachedAttachment> cachedAtts = [];
                  const maxAttachmentBytes = 10 * 1024 * 1024; // 10MB per attachment cap
                  for (final ci in infos) {
                    try {
                      final bytes = await AttachmentFetcher.fetchBytes(
                        message: refreshed,
                        content: ci,
                        mailbox: mailbox,
                      );
                      if (bytes == null) continue;
                      if (bytes.length > maxAttachmentBytes) continue;
                      final path = await MessageContentStore.instance.saveAttachmentBytes(
                        accountEmail: accountEmail,
                        mailboxPath: mailboxPath,
                        uidValidity: uidValidity,
                        uid: refreshed.uid ?? -1,
                        fileName: ci.fileName ?? 'attachment',
                        bytes: bytes,
                        uniquePartId: ci.fetchId,
                        contentId: refreshed.getPart(ci.fetchId)?.getHeaderValue('content-id'),
                        mimeType: ci.contentType?.mediaType.toString(),
                        size: ci.size ?? bytes.length,
                      );
                      cachedAtts.add(CachedAttachment(
                        contentId: null,
                        fileName: ci.fileName ?? 'attachment',
                        mimeType: ci.contentType?.mediaType.toString() ?? 'application/octet-stream',
                        sizeBytes: ci.size ?? bytes.length,
                        isInline: false,
                        filePath: path,
                      ));
                    } catch (_) {}
                  }

                  if ((sanitizedHtml != null && sanitizedHtml.isNotEmpty) || (plain != null && plain.isNotEmpty) || cachedAtts.isNotEmpty) {
                    await MessageContentStore.instance.upsertContent(
                      accountEmail: accountEmail,
                      mailboxPath: mailboxPath,
                      uidValidity: uidValidity,
                      uid: refreshed.uid ?? -1,
                      plainText: plain,
                      htmlSanitizedBlocked: sanitizedHtml,
                      sanitizedVersion: 1,
                      attachments: cachedAtts,
                    );
                  }
                } catch (_) {}

                return refreshed;
              } catch (e) {
                fetchRetries--;
                if (kDebugMode) {
                  print('Attachment refetch failed for UID ${message.uid}: $e (retries left: $fetchRetries)');
                }
                if (fetchRetries == 0) {
                  break;
                }
                await Future.delayed(const Duration(milliseconds: 500));
                // Re-select mailbox defensively
                if (mailbox != null) {
                  try { await mailService.client.selectMailbox(mailbox!).timeout(const Duration(seconds: 8)); } catch (_) {}
                }
              }
            }

            // Fall back to cached content if refetch failed or timed out
            return cachedMessage;
          }

          return cachedMessage;
        }
      }
      
      // CRITICAL FIX: Validate message UID before fetching
      if (message.uid == null) {
        if (kDebugMode) {
          print('DEBUG: Message UID is null, returning original message');
        }
        // Return the original message if UID is null
        return message;
      }
      
      // If offline, avoid network fetch and return cached/original message
      if (!InternetService.instance.connected) {
        if (message.uid != null) {
          final cachedMessage = await EmailCacheService.instance.getCachedEmail(message.uid!);
          if (cachedMessage != null) return cachedMessage;
        }
        return message;
      }

      // Ensure we're connected with retry logic and explicit timeouts
      int connectionRetries = 3;
      while (!mailService.client.isConnected && connectionRetries > 0) {
        try {
          await mailService.connect().timeout(const Duration(seconds: 12));
          break;
        } catch (e) {
          connectionRetries--;
          if (connectionRetries == 0) rethrow;
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      
      // CRITICAL FIX: Validate and ensure correct mailbox is selected
      if (mailbox != null) {
        final currentMailbox = mailService.client.selectedMailbox;
        if (currentMailbox == null || currentMailbox.path != mailbox!.path) {
          if (kDebugMode) {
            print('Selecting mailbox: ${mailbox!.path} (current: ${currentMailbox?.path})');
          }
          await mailService.client.selectMailbox(mailbox!).timeout(const Duration(seconds: 8));
          
          // Wait a moment for mailbox selection to complete
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
      
      // CRITICAL FIX: Add logging for debugging UID fetch issues
      if (kDebugMode) {
        print('Preparing to fetch message content for UID ${message.uid} in mailbox ${mailbox?.path}');
      }
      
      // CRITICAL FIX: Fetch message content with retry logic and proper error handling
      int fetchRetries = 3;
      MimeMessage? fetchedMessage;
      
      while (fetchRetries > 0) {
        try {
          if (kDebugMode) {
            print('Fetching message contents for UID ${message.uid} (attempt ${4 - fetchRetries})');
          }
          
          fetchedMessage = await mailService.client.fetchMessageContents(message).timeout(const Duration(seconds: 20));
          
          if (kDebugMode) {
            print('Successfully fetched message contents for UID ${message.uid}');
          }
          
          break; // Success, exit retry loop
        } catch (e) {
          fetchRetries--;
          if (kDebugMode) {
            print('Fetch attempt failed for UID ${message.uid}: $e (retries left: $fetchRetries)');
          }
          
          if (fetchRetries == 0) {
            // Final attempt failed, throw with more context
            throw Exception('Failed to fetch message content after 3 attempts. UID: ${message.uid}, Error: $e');
          }
          
          // Wait before retry
          await Future.delayed(Duration(milliseconds: 500 * (4 - fetchRetries)));
          
          // Re-select mailbox before retry to ensure proper context
          if (mailbox != null) {
            try {
              await mailService.client.selectMailbox(mailbox!).timeout(const Duration(seconds: 8));
              await Future.delayed(const Duration(milliseconds: 100));
            } catch (selectError) {
              if (kDebugMode) {
                print('Mailbox re-selection failed during retry: $selectError');
              }
            }
          }
        }
      }
      
      if (fetchedMessage == null) {
        throw Exception('Unexpected error: fetchedMessage is null after retry logic');
      }
      
      // PERFORMANCE: After fetching, persist offline body + attachments
      try {
        final rawHtml = fetchedMessage.decodeTextHtmlPart();
        final blockRemote = true; // store blocked variant only
        String? htmlStore;
        String? plainStore = fetchedMessage.decodeTextPlainPart();
        if (rawHtml != null && rawHtml.trim().isNotEmpty) {
          // Pre-sanitize large HTML off the main thread to reduce jank
          String preprocessed = rawHtml;
          if (rawHtml.length > 100 * 1024) {
            try {
              preprocessed = await MessageContentStore.sanitizeHtmlInIsolate(rawHtml);
            } catch (_) {}
          }
          final deviceWidthPx = 1024.0; // storage-time normalization only
          final enhanced = HtmlEnhancer.enhanceEmailHtml(
            message: fetchedMessage,
            rawHtml: preprocessed,
            darkMode: Theme.of(Get.context!).brightness == Brightness.dark,
            blockRemoteImages: blockRemote,
            deviceWidthPx: deviceWidthPx,
          );
          htmlStore = enhanced.html;
        }

        // Save attachments (bounded size)
        final infos = fetchedMessage.findContentInfo();
        final List<CachedAttachment> cachedAtts = [];
        const maxAttachmentBytes = 10 * 1024 * 1024; // 10MB per attachment cap
        for (final ci in infos) {
          try {
            final bytes = await AttachmentFetcher.fetchBytes(
              message: fetchedMessage,
              content: ci,
              mailbox: mailbox,
            );
            if (bytes == null) continue;
            if (bytes.length > maxAttachmentBytes) continue; // skip huge
            final path = await MessageContentStore.instance.saveAttachmentBytes(
              accountEmail: accountEmail,
              mailboxPath: mailboxPath,
              uidValidity: uidValidity,
              uid: fetchedMessage.uid ?? -1,
              fileName: ci.fileName ?? 'attachment',
              bytes: bytes,
              uniquePartId: ci.fetchId,
              contentId: fetchedMessage.getPart(ci.fetchId)?.getHeaderValue('content-id'),
              mimeType: ci.contentType?.mediaType.toString(),
              size: ci.size ?? bytes.length,
            );
            cachedAtts.add(CachedAttachment(
              contentId: null,
              fileName: ci.fileName ?? 'attachment',
              mimeType: ci.contentType?.mediaType.toString() ?? 'application/octet-stream',
              sizeBytes: ci.size ?? bytes.length,
              isInline: false,
              filePath: path,
            ));
          } catch (_) {}
        }

        if ((htmlStore != null && htmlStore.isNotEmpty) || (plainStore != null && plainStore.isNotEmpty) || cachedAtts.isNotEmpty) {
          await MessageContentStore.instance.upsertContent(
            accountEmail: accountEmail,
            mailboxPath: mailboxPath,
            uidValidity: uidValidity,
            uid: fetchedMessage.uid ?? -1,
            plainText: plainStore,
            htmlSanitizedBlocked: htmlStore,
            sanitizedVersion: 1,
            attachments: cachedAtts,
          );
        }
      } catch (_) {}

      // PERFORMANCE OPTIMIZATION: Cache the fetched message
      if (fetchedMessage.uid != null) {
        try {
          await EmailCacheService.instance.cacheEmail(fetchedMessage);
        } catch (cacheError) {
          if (kDebugMode) {
            print('Warning: Failed to cache message UID ${fetchedMessage.uid}: $cacheError');
          }
          // Don't fail the entire operation if caching fails
        }
      }
      
      return fetchedMessage;
      
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching message content: $e');
      }
      // Offline-first: return the original message so UI can render cached content
      return message;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MimeMessage>(
      future: _fetchMessageContent(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasError) {
          // Fall back to offline cached content if available
          return FutureBuilder<CachedMessageContent?>(
            future: (message.uid != null)
                ? MessageContentStore.instance.getContent(
                    accountEmail: MailService.instance.account.email,
                    mailboxPath: mailbox?.encodedPath ?? mailbox?.path ?? 'INBOX',
                    uidValidity: mailbox?.uidValidity ?? 0,
                    uid: message.uid!,
                  )
                : Future.value(null),
            builder: (ctx, cacheSnap) {
              final cached = cacheSnap.data;
              if (cacheSnap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (cached != null && ((cached.htmlSanitizedBlocked?.isNotEmpty ?? false) || (cached.plainText?.isNotEmpty ?? false))) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _offlineBanner(context),
                  if (showBodyViewer)
                    EnterpriseMessageViewer(
                      mimeMessage: message,
                      enableDarkMode: Theme.of(context).brightness == Brightness.dark,
                      blockExternalImages: true,
                      textScale: MediaQuery.of(context).textScaler.scale(1.0),
                      initialHtml: cached.htmlSanitizedBlocked,
                      initialHtmlPath: cached.htmlFilePath,
                    ),
                    if (cached.attachments.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.attach_file, size: 20, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text('Offline attachments (${cached.attachments.length})',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...cached.attachments.map((a) => ListTile(
                                  leading: const Icon(Icons.insert_drive_file_rounded),
                                  title: Text(a.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text('${a.mimeType} • ${(a.sizeBytes / 1024).toStringAsFixed(1)} KB'),
                                  onTap: () {
                                    OpenAppFile.open(a.filePath);
                                  },
                                  trailing: IconButton(
                                    icon: const Icon(Icons.share_rounded),
                                    onPressed: () async {
                                      try {
                                        await Share.shareXFiles([XFile(a.filePath)], text: a.fileName);
                                      } catch (_) {}
                                    },
                                  ),
                                )),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                  ],
                );
              }
              // No cached content -> show error UI
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        'Error loading message content: ${snapshot.error}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.errorColor),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Get.forceAppUpdate(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        } else if (snapshot.hasData && snapshot.data != null) {
          // Enhanced email content display with proper structure
          return FutureBuilder<CachedMessageContent?>(
            future: (message.uid != null)
                ? MessageContentStore.instance.getContent(
                    accountEmail: MailService.instance.account.email,
                    mailboxPath: mailbox?.encodedPath ?? mailbox?.path ?? 'INBOX',
                    uidValidity: mailbox?.uidValidity ?? 0,
                    uid: message.uid!,
                  )
                : Future.value(null),
            builder: (ctx, cacheSnap) {
              final cached = cacheSnap.data;
              final initialHtml = cached?.htmlSanitizedBlocked;
              final initialHtmlPath = cached?.htmlFilePath;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (initialHtmlPath != null || (initialHtml != null && ((snapshot.data?.decodeTextHtmlPart()?.trim().isNotEmpty ?? false) == false)))
                    _offlineBanner(context),
                  // WebView-first enterprise viewer for best fidelity
                  if (showBodyViewer)
                    EnterpriseMessageViewer(
                      mimeMessage: snapshot.data!,
                      enableDarkMode: Theme.of(context).brightness == Brightness.dark,
                      blockExternalImages: true,
                      textScale: MediaQuery.of(context).textScaler.scale(1.0),
                      initialHtml: initialHtml,
                      initialHtmlPath: initialHtmlPath,
                    ),

                  // Cached offline attachments (if available)
                  // Show when offline OR when MIME has no attachment parts to avoid empty state
                  if (cached != null && cached.attachments.isNotEmpty &&
                      (!InternetService.instance.connected || ((snapshot.data?.findContentInfo(disposition: ContentDisposition.attachment).isEmpty ?? true))))
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.attach_file, size: 20, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Text('Offline attachments (${cached.attachments.length})',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ...cached.attachments.map((a) => ListTile(
                                leading: const Icon(Icons.insert_drive_file_rounded),
                                title: Text(a.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                                subtitle: Text('${a.mimeType} • ${(a.sizeBytes / 1024).toStringAsFixed(1)} KB'),
                                onTap: () {
                                  OpenAppFile.open(a.filePath);
                                },
                                trailing: IconButton(
                                  icon: const Icon(Icons.share_rounded),
                                  onPressed: () async {
                                    try {
                                      await Share.shareXFiles([XFile(a.filePath)], text: a.fileName);
                                    } catch (_) {}
                                  },
                                ),
                              )),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),

                  // Online attachments via MIME (if present)
                  if (showAttachmentsList)
                    EnhancedAttachmentViewer(
                      mimeMessage: snapshot.data!,
                      showInline: false,
                      maxAttachmentsToShow: 20,
                    ),
                ],
              );
            },
          );
        } else {
          return const Center(
            child: Text('No message content available'),
          );
        }
      },
    );
  }

  Widget _offlineBanner(BuildContext context) {
    return Container
      (
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Showing offline content from cache',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class AttachmentTile extends StatefulWidget {
  final ContentInfo contentInfo;
  final MimeMessage mimeMessage;

  const AttachmentTile({
    super.key,
    required this.contentInfo,
    required this.mimeMessage
  });

  @override
  State<AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends State<AttachmentTile> {
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final fileName = widget.contentInfo.fileName ?? 'Unknown file';
    final fileSize = widget.contentInfo.size != null
        ? _formatFileSize(widget.contentInfo.size!)
        : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        side: const BorderSide(color: AppTheme.dividerColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        onTap: _isLoading ? null : () => _handleAttachmentTap(context),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                ),
                child: Center(
                  child: Icon(
                    getAttachmentIcon(fileName),
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (fileSize.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        fileSize,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.errorColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download_rounded),
                      onPressed: () => _handleAttachmentTap(context),
                      tooltip: 'Download',
                      color: AppTheme.primaryColor,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded),
                      onPressed: () => _handleShareAttachment(context),
                      tooltip: 'Share',
                      color: AppTheme.primaryColor,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAttachmentTap(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      MimePart? mimePart = widget.mimeMessage.getPart(widget.contentInfo.fetchId);
      if (mimePart != null) {
        Uint8List? uint8List = mimePart.decodeContentBinary();
        if (uint8List != null) {
          final success = await saveAndOpenFile(
            context,
            uint8List,
            widget.contentInfo.fileName ?? 'file',
          );

          if (!success && mounted) {
            setState(() {
              _error = 'Failed to open file';
            });
          }
        } else {
          setState(() {
            _error = 'Could not decode file content';
          });
        }
      } else {
        setState(() {
          _error = 'Attachment not found';
        });
      }
    } catch (e) {
      log('Error opening attachment: $e');
      if (mounted) {
        setState(() {
          _error = 'Error: ${e.toString().split('\n').first}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleShareAttachment(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      MimePart? mimePart = widget.mimeMessage.getPart(widget.contentInfo.fetchId);
      if (mimePart != null) {
        Uint8List? uint8List = mimePart.decodeContentBinary();
        if (uint8List != null) {
          final tempFile = await _saveTempFile(
            uint8List,
            widget.contentInfo.fileName ?? 'file',
          );

          if (tempFile != null) {
            await Share.shareXFiles(
              [XFile(tempFile.path)],
              text: 'Sharing ${widget.contentInfo.fileName}',
            );
          } else {
            setState(() {
              _error = 'Could not create temporary file';
            });
          }
        } else {
          setState(() {
            _error = 'Could not decode file content';
          });
        }
      } else {
        setState(() {
          _error = 'Attachment not found';
        });
      }
    } catch (e) {
      log('Error sharing attachment: $e');
      if (mounted) {
        setState(() {
          _error = 'Error: ${e.toString().split('\n').first}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<File?> _saveTempFile(Uint8List data, String fileName) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(data);
      return file;
    } catch (e) {
      log('Error saving temp file: $e');
      return null;
    }
  }

  String _formatFileSize(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<bool> saveAndOpenFile(
      BuildContext context, Uint8List uint8List, String fileName) async {
    try {
      // First try to save to app's cache directory (doesn't require permissions)
      final cacheDir = await getApplicationCacheDirectory();
      final appDir = Directory('${cacheDir.path}/NetxMail');

      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }

      final cacheFile = File('${appDir.path}/$fileName');
      await cacheFile.writeAsBytes(uint8List);

      // Try to open the file from cache
      try {
        await OpenAppFile.open(cacheFile.path);

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening $fileName'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
        return true;
      } catch (e) {
        log('Could not open file from cache: $e');
        // If opening fails, try to save to a more accessible location
      }

      // Try to get storage permission for a better location
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (status.isGranted || status.isLimited) {
          // On Android, try to save to Downloads folder
          Directory? downloadsDir;

          try {
            // Try to get the Downloads directory
            downloadsDir = Directory('/storage/emulated/0/Download');
            if (!await downloadsDir.exists()) {
              downloadsDir = await getExternalStorageDirectory();
            }
          } catch (e) {
            log('Error getting downloads directory: $e');
            downloadsDir = await getExternalStorageDirectory();
          }

          if (downloadsDir != null) {
            final downloadFile = File('${downloadsDir.path}/$fileName');
            await downloadFile.writeAsBytes(uint8List);

            try {
              await OpenAppFile.open(downloadFile.path);

              // Show success message
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Opening $fileName from Downloads'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              }
              return true;
            } catch (e) {
              log('Could not open file from Downloads: $e');

              // Show file location
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('File saved to ${downloadFile.path}'),
                    backgroundColor: AppTheme.infoColor,
                    duration: const Duration(seconds: 5),
                    action: SnackBarAction(
                      label: 'OK',
                      textColor: Colors.white,
                      onPressed: () {},
                    ),
                  ),
                );
              }
              return true;
            }
          }
        } else {
          // Permission denied, show dialog with instructions
          if (context.mounted) {
            _showPermissionDeniedDialog(context, 'storage');
          }
          return false;
        }
      } else if (Platform.isIOS) {
        final status = await Permission.photos.request();
        if (status.isGranted || status.isLimited) {
          // On iOS, try to use share to save the file
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/$fileName');
          await tempFile.writeAsBytes(uint8List);

          // Use share to let the user decide where to save it
          if (context.mounted) {
            // ignore: deprecated_member_use
            await Share.shareXFiles(
              [XFile(tempFile.path)],
              text: 'Save or open $fileName',
            );
            return true;
          }
        } else {
          // Permission denied, show dialog with instructions
          if (context.mounted) {
            _showPermissionDeniedDialog(context, 'photos');
          }
          return false;
        }
      }

      // If all else fails, just share the file
      if (context.mounted) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(uint8List);

        await Share.shareXFiles(
          [XFile(tempFile.path)],
          text: 'Save or open $fileName',
        );
        return true;
      }

      return false;
    } catch (e) {
      log('Error saving file: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving file: ${e.toString().split('\n').first}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return false;
    }
  }

  void _showPermissionDeniedDialog(BuildContext context, String permissionType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(
            'To save attachments, we need permission to access your ${permissionType == 'photos' ? 'photos' : 'files'}. '
                'Please grant this permission in your device settings.'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

IconData getAttachmentIcon(String? file) {
  if (file == null) return Icons.attach_file;

  String ext = file.split(".").last.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
    case 'jfif':
    case 'pjpeg':
    case 'pjp':
    case 'png':
    case 'sgv':
    case 'gif':
    case 'webp':
    case 'bmp':
    case 'tiff':
      return Icons.image_rounded;
    case 'pdf':
      return Icons.picture_as_pdf_rounded;
    case 'pptx':
    case 'pptm':
    case 'ppt':
      return FontAwesomeIcons.solidFilePowerpoint;
    case 'zip':
    case 'rar':
    case '7z':
    case 'tar':
    case 'gz':
      return FontAwesomeIcons.fileZipper;
    case 'docx':
    case 'doc':
    case 'odt':
      return FontAwesomeIcons.fileWord;
    case 'txt':
    case 'rtf':
    case 'tex':
    case 'md':
      return FontAwesomeIcons.fileLines;
    case 'xls':
    case 'xlsx':
    case 'xlsm':
    case 'xlsb':
    case 'xltx':
    case 'csv':
      return FontAwesomeIcons.fileExcel;
    case 'mp3':
    case 'mpeg-1':
    case 'aac':
    case 'flac':
    case 'alac':
    case 'wav':
    case 'aiff':
    case 'dsd':
    case 'ogg':
      return FontAwesomeIcons.fileAudio;
    case 'mp4':
    case 'mov':
    case 'wmv':
    case 'avi':
    case 'avchd':
    case 'flv':
    case 'mkv':
    case 'html5':
    case 'webm':
    case 'swf':
      return FontAwesomeIcons.fileVideo;
    case 'html':
    case 'htm':
    case 'css':
    case 'js':
    case 'json':
    case 'xml':
      return FontAwesomeIcons.fileCode;
    default:
      return Icons.insert_drive_file_rounded;
  }
}
