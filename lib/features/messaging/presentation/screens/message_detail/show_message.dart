import 'dart:io';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/views/view/showmessage/widgets/inbox_app_bar.dart';
import 'package:wahda_bank/views/view/showmessage/widgets/inbox_bottom_navbar.dart';
import 'package:wahda_bank/views/view/showmessage/widgets/mail_meta_tile.dart';
import 'package:wahda_bank/views/view/showmessage/widgets/attachment_carousel.dart';
import 'package:wahda_bank/views/view/showmessage/widgets/thread_viewer.dart';
import 'package:wahda_bank/widgets/enterprise_message_viewer.dart';
import 'package:wahda_bank/services/message_content_store.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/services/sender_trust.dart';
import 'package:wahda_bank/services/offline_http_server.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';
import 'package:wahda_bank/shared/utils/hashing.dart';
import 'package:wahda_bank/design_system/components/app_scaffold.dart';
import 'package:wahda_bank/observability/perf/message_detail_perf_sampler.dart';

class ShowMessage extends StatefulWidget {
  const ShowMessage({super.key, required this.message, required this.mailbox});
  final MimeMessage message;
  final Mailbox mailbox;

  @override
  State<ShowMessage> createState() => _ShowMessageState();
}

class _ShowMessageState extends State<ShowMessage> {
  late MimeMessage message;
  late Mailbox mailbox;

  DateTime? _telemetryStart;
  bool _telemetrySent = false;

  // P27 perf sampling
  MessageDetailPerfSampler? _renderPerf;
  MessageDetailPerfSampler? _scrollPerf;

  // Offline-first content from store
  String? _initialHtml;
  String? _initialHtmlPath;
  bool _loadingContent = false;
  ValueNotifier<int>? _metaNotifier;
  int _loadGen = 0; // generation token to avoid stale state after fast swipes

  // Retry small inline content shortly after first open (to catch post-fetch updates)
  int _contentReloadRetries = 0;

  @override
  void initState() {
    super.initState();
    message = widget.message;
    mailbox = widget.mailbox;
    _telemetryStart = DateTime.now();
    // Mark as read if not already
    try {
      if (!(message.isSeen)) {
        final ctrl = Get.find<MailBoxController>();
        // fire-and-forget
        ctrl.markAsReadUnread([message], mailbox, true);
      }
    } catch (_) {}

    // Start perf sampling on first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _renderPerf = MessageDetailPerfSampler(opName: 'message_detail_render')
        ..start();
      final primary = PrimaryScrollController.of(context);
      if (primary != null) {
        _scrollPerf = MessageDetailPerfSampler(
          opName: 'message_detail_body_scroll',
        )..start();
      }
    });

    // Listen for meta updates (preview/x-ready/etc.) to refresh content
    try {
      final ctrl = Get.find<MailBoxController>();
      _metaNotifier = ctrl.getMessageMetaNotifier(mailbox, message);
      _metaNotifier!.addListener(_loadCachedContent);
    } catch (_) {}

    // Proactively prefetch full content for smooth open
    try {
      Get.find<MailBoxController>().prefetchMessageContent(
        mailbox,
        message,
        quiet: true,
      );
    } catch (_) {}
    // Load cached content immediately
    _loadCachedContent();
  }

  Future<void> _ensureSelectedMailbox() async {
    try {
      final mailService = MailService.instance;
      if (!mailService.client.isConnected) {
        try {
          await mailService.connect().timeout(const Duration(seconds: 10));
        } catch (_) {}
      }
      try {
        await mailService.client
            .selectMailbox(mailbox)
            .timeout(const Duration(seconds: 8));
      } catch (_) {}
    } catch (_) {}
  }

  void _loadCachedContent() async {
    if (_loadingContent) return;
    _loadingContent = true;
    final int gen = ++_loadGen; // capture generation for this load
    try {
      final accountEmail = MailService.instance.account.email;
      final mailboxPath =
          mailbox.encodedPath.isNotEmpty ? mailbox.encodedPath : (mailbox.path);
      final uidValidity = mailbox.uidValidity ?? 0;
      final uid = message.uid ?? -1;
      if (uid <= 0) {
        if (!mounted || gen != _loadGen) return;
        setState(() {
          _initialHtml = message.decodeTextHtmlPart();
          _initialHtmlPath = null;
        });
        _maybeScheduleRetry(
          html: _initialHtml,
          htmlPath: _initialHtmlPath,
          uid: uid,
        );
      } else {
        final store = MessageContentStore.instance;
        final cached = await store.getContent(
          accountEmail: accountEmail,
          mailboxPath: mailboxPath,
          uidValidity: uidValidity,
          uid: uid,
        );
        if (!mounted || gen != _loadGen) return;

        // Try to get the most up-to-date message instance (full body) from controller cache
        MimeMessage effectiveMsg = message;
        try {
          final ctrl = Get.find<MailBoxController>();
          MimeMessage? found;
          // 1) Prefer same mailbox list
          final list = ctrl.emails[mailbox] ?? const <MimeMessage>[];
          final idx = list.indexWhere(
            (m) =>
                (uid > 0 && m.uid == uid) ||
                ((message.sequenceId != null) &&
                    m.sequenceId == message.sequenceId),
          );
          if (idx != -1) {
            found = list[idx];
          }
          // 2) Fallback: search across all mailboxes by UID/sequenceId to avoid mailbox identity mismatch
          if (found == null) {
            for (final entry in ctrl.emails.entries) {
              final lst = entry.value;
              final j = lst.indexWhere(
                (m) =>
                    (uid > 0 && m.uid == uid) ||
                    ((message.sequenceId != null) &&
                        m.sequenceId == message.sequenceId),
              );
              if (j != -1) {
                found = lst[j];
                break;
              }
            }
          }
          if (found != null) effectiveMsg = found;
        } catch (_) {}

        // Determine trust (controls remote image policy)
        String senderKey = _extractSenderKey(effectiveMsg);
        final trusted = SenderTrustService.instance.isTrusted(senderKey);
        final allowRemote =
            trusted; // user pref currently: allow only for trusted senders

        // Enterprise policy: when remote images are allowed, prefer RAW HTML to preserve http/https URLs.
        // Otherwise, use sanitized (blocked) HTML with CSP.
        String? html;
        if (allowRemote) {
          html = effectiveMsg.decodeTextHtmlPart();
          if (html == null || html.trim().isEmpty) {
            // Fallback to sanitized HTML from cache if available
            if ((cached?.htmlSanitizedBlocked?.trim().isNotEmpty ?? false)) {
              html = cached!.htmlSanitizedBlocked;
              if (kDebugMode) {
                // ignore: avoid_print
                print(
                  'VIEWER:sanitized_fallback uid=$uid -> RAW empty; using sanitized HTML from cache',
                );
              }
            }
          } else if (kDebugMode &&
              (cached?.htmlSanitizedBlocked?.isNotEmpty ?? false)) {
            // ignore: avoid_print
            print(
              'VIEWER:trust_fallback uid=$uid -> prefer RAW HTML over sanitized for remote images',
            );
          }
        } else {
          html =
              cached?.htmlSanitizedBlocked ?? effectiveMsg.decodeTextHtmlPart();
        }
        // Last-resort inline fallback: use cached plain text if no HTML available
        if (html == null || html.trim().isEmpty) {
          final plain = cached?.plainText ?? effectiveMsg.decodeTextPlainPart();
          if (plain != null && plain.trim().isNotEmpty) {
            html = _wrapPlainAsHtml(plain);
            if (kDebugMode) {
              // ignore: avoid_print
              print(
                'VIEWER:plain_fallback uid=$uid -> using cached/plain text as HTML',
              );
            }
          }
        }

        // Emit telemetry once content has been determined from cache/plain
        _sendOpenTelemetryOnce();

        // On-demand fetch fallback: if still empty, fetch this message body immediately
        if (html == null || html.trim().isEmpty) {
          try {
            await _ensureSelectedMailbox();
            final mailService = MailService.instance;
            final seq = MessageSequence.fromMessage(message);
            List<MimeMessage> fetched = const <MimeMessage>[];
            try {
              fetched = await mailService.client
                  .fetchMessageSequence(
                    seq,
                    fetchPreference: FetchPreference.fullWhenWithinSize,
                  )
                  .timeout(
                    const Duration(seconds: 15),
                    onTimeout: () => <MimeMessage>[],
                  );
            } catch (_) {
              // Retry once after re-select
              try {
                await _ensureSelectedMailbox();
              } catch (_) {}
              try {
                fetched = await mailService.client
                    .fetchMessageSequence(
                      seq,
                      fetchPreference: FetchPreference.fullWhenWithinSize,
                    )
                    .timeout(
                      const Duration(seconds: 12),
                      onTimeout: () => <MimeMessage>[],
                    );
              } catch (_) {}
            }
            if (fetched.isNotEmpty) {
              final full = fetched.first;
              effectiveMsg = full; // prefer the freshly fetched full message
              html = full.decodeTextHtmlPart();
              if (html == null || html.trim().isEmpty) {
                final plain = full.decodeTextPlainPart();
                if (plain != null && plain.trim().isNotEmpty) {
                  html = _wrapPlainAsHtml(plain);
                  if (kDebugMode) {
                    // ignore: avoid_print
                    print(
                      'VIEWER:plain_fallback uid=$uid -> using on-demand fetched plain text as HTML',
                    );
                  }
                }
              }
              // Emit telemetry after on-demand fetch resolves content
              _sendOpenTelemetryOnce();
            }
          } catch (_) {}
        }

        String? htmlPath = cached?.htmlFilePath;
        int version = cached?.sanitizedVersion ?? 0;

        // If DB returned no file path, try to locate an existing offline file deterministically
        try {
          if ((htmlPath == null || htmlPath.isEmpty) && uid > 0) {
            final pth = await _calcOfflineHtmlPathIfExists(
              accountEmail,
              mailboxPath,
              uidValidity,
              uid,
            );
            if (pth != null) {
              htmlPath = pth;
              version = version == 0 ? 2 : version;
              if (kDebugMode) {
                // ignore: avoid_print
                print(
                  'VIEWER:path_heal uid=$uid -> found existing offline file: $htmlPath',
                );
              }
              // Best-effort: persist the path back to DB for future loads
              try {
                await store.upsertContent(
                  accountEmail: accountEmail,
                  mailboxPath: mailboxPath,
                  uidValidity: uidValidity,
                  uid: uid,
                  plainText: cached?.plainText,
                  htmlSanitizedBlocked: cached?.htmlSanitizedBlocked ?? html,
                  htmlFilePath: htmlPath,
                  sanitizedVersion: version == 0 ? 2 : version,
                  attachments: cached?.attachments ?? const [],
                );
              } catch (_) {}
            }
          }
        } catch (_) {}

        if (kDebugMode) {
          int htmlLen = html?.length ?? 0;
          bool exists = false;
          int size = -1;
          try {
            if (htmlPath != null && htmlPath.isNotEmpty) {
              final f = File(htmlPath);
              exists = f.existsSync();
              if (exists) size = f.statSync().size;
            }
          } catch (_) {}
          // ignore: avoid_print
          print(
            'VIEWER:cache uid=$uid box=$mailboxPath v=$version trusted=$trusted allowRemote=$allowRemote htmlLen=$htmlLen htmlPath=$htmlPath exists=$exists size=$size',
          );
        }

        // Build local HTTP URL for viewer on non-iOS platforms ONLY when we have something cached to serve
        String? serverUrl;
        try {
          if (!Platform.isIOS && uid > 0) {
            bool hasCachedMeaningful = false;
            try {
              final hp = htmlPath;
              if (hp != null && hp.isNotEmpty && File(hp).existsSync()) {
                hasCachedMeaningful = true;
              }
            } catch (_) {}
            if (!hasCachedMeaningful) {
              final hasInline =
                  (cached?.htmlSanitizedBlocked?.trim().isNotEmpty ?? false) ||
                  (cached?.plainText?.trim().isNotEmpty ?? false);
              hasCachedMeaningful = hasInline;
            }
            if (hasCachedMeaningful) {
              final port =
                  OfflineHttpServer.instance.port ??
                  await OfflineHttpServer.instance.start();
              final accountEnc = Uri.encodeComponent(accountEmail);
              final boxEnc = Uri.encodeComponent(mailboxPath);
              final allow = allowRemote ? '1' : '0';
              serverUrl =
                  'http://127.0.0.1:$port/message/$accountEnc/$boxEnc/$uidValidity/$uid.html?allowRemote=$allow';
            }
          }
        } catch (_) {}

        // Rebuild outdated/missing offline HTML files with CSS wrapper
        bool needRebuild = false;
        if (htmlPath != null && htmlPath.isNotEmpty) {
          try {
            final exists = File(htmlPath).existsSync();
            if (!exists) needRebuild = true;
          } catch (_) {}
        }
        if (version < 2 && htmlPath != null && htmlPath.isNotEmpty) {
          needRebuild = true;
        }
        if ((htmlPath == null || htmlPath.isEmpty) &&
            (html != null && html.trim().isNotEmpty)) {
          // No file yet: materialize one for fast load
          needRebuild = true;
        }
        // If a file exists but its CSP remote-image policy doesn't match current trust state, rebuild it
        if (htmlPath != null && htmlPath.isNotEmpty) {
          try {
            final file = File(htmlPath);
            if (file.existsSync()) {
              final content = file.readAsStringSync();
              final allowsHttp = content.contains(
                "img-src 'self' data: about: cid: http: https:",
              );
              if (allowsHttp != allowRemote) {
                needRebuild = true;
                if (kDebugMode) {
                  // ignore: avoid_print
                  print(
                    'VIEWER:policy_mismatch uid=$uid -> file allowsHttp=$allowsHttp, allowRemote=$allowRemote => rebuild',
                  );
                }
              }
            }
          } catch (_) {}
        }

        if (needRebuild) {
          if (kDebugMode) {
            // ignore: avoid_print
            print(
              'VIEWER:materialize uid=$uid -> writing offline HTML file (prevPath=$htmlPath, v=$version, allowRemote=$allowRemote)',
            );
          }
          try {
            // Enterprise policy: if remote images are allowed, always prefer RAW HTML for materialization.
            String innerHtml =
                allowRemote
                    ? (effectiveMsg.decodeTextHtmlPart() ?? '')
                    : (html ?? '');
            // If still empty, fall back to cached plain text
            if (innerHtml.trim().isEmpty) {
              final plain =
                  cached?.plainText ?? effectiveMsg.decodeTextPlainPart() ?? '';
              if (plain.trim().isNotEmpty) {
                innerHtml = _wrapPlainAsHtml(plain);
              }
            }
            // Materialize the offline HTML document; respect remote policy
            final newPath = await store.saveOfflineHtmlDocument(
              accountEmail: accountEmail,
              mailboxPath: mailboxPath,
              uidValidity: uidValidity,
              uid: uid,
              sanitizedInnerHtml: innerHtml,
              blockRemote: !allowRemote,
            );
            // Persist updated path and bump version (keep existing cached.htmlSanitizedBlocked as-is)
            await store.upsertContent(
              accountEmail: accountEmail,
              mailboxPath: mailboxPath,
              uidValidity: uidValidity,
              uid: uid,
              plainText: cached?.plainText,
              htmlSanitizedBlocked: cached?.htmlSanitizedBlocked ?? html,
              htmlFilePath: newPath,
              sanitizedVersion: 2,
              attachments: cached?.attachments ?? const [],
              forceMaterialize: false,
            );
            if (kDebugMode) {
              try {
                final st = File(newPath).statSync();
                // ignore: avoid_print
                print(
                  'VIEWER:materialized uid=$uid -> $newPath (${st.size} bytes)',
                );
              } catch (_) {}
            }
            htmlPath = newPath;
            version = 2;
          } catch (e) {
            if (kDebugMode) {
              // ignore: avoid_print
              print('VIEWER:materialize error uid=$uid: $e');
            }
          }
        }

        if (kDebugMode) {
          final hl = html?.length ?? 0;
          bool exists = false;
          int size = -1;
          try {
            if (htmlPath != null && htmlPath.isNotEmpty) {
              final f = File(htmlPath);
              exists = f.existsSync();
              if (exists) size = f.statSync().size;
            }
          } catch (_) {}
          // ignore: avoid_print
          print(
            'VIEWER:setState uid=$uid htmlLen=$hl htmlPath=$htmlPath exists=$exists size=$size',
          );
        }
        if (!mounted || gen != _loadGen) return;
        setState(() {
          // Update message to the fullest version we know about so inline viewer can decode from it on iOS
          message = effectiveMsg;
          _initialHtml = html;
          _initialHtmlPath = serverUrl ?? htmlPath;
        });
        _maybeScheduleRetry(html: html, htmlPath: htmlPath, uid: uid);
      }
    } catch (_) {
      if (!mounted) return;
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _initialHtml = message.decodeTextHtmlPart();
        _initialHtmlPath = null;
      });
      _maybeScheduleRetry(
        html: _initialHtml,
        htmlPath: _initialHtmlPath,
        uid: message.uid ?? -1,
      );
    } finally {
      _loadingContent = false;
    }
  }

  // Compute expected offline HTML path and return it if it exists
  Future<String?> _calcOfflineHtmlPathIfExists(
    String accountEmail,
    String mailboxPath,
    int uidValidity,
    int uid,
  ) async {
    try {
      final base = await getApplicationCacheDirectory();
      final safeBox = mailboxPath.replaceAll('/', '_');
      final file = File(
        p.join(
          base.path,
          'offline_html',
          accountEmail,
          safeBox,
          '$uidValidity',
          'msg_$uid.html',
        ),
      );
      if (await file.exists()) {
        return file.path;
      }
    } catch (_) {}
    return null;
  }

  String _escapeHtml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  String _wrapPlainAsHtml(String s) =>
      '<pre class="wb-pre">${_escapeHtml(s)}</pre>';

  void _maybeScheduleRetry({
    required String? html,
    required String? htmlPath,
    required int uid,
  }) {
    try {
      if (uid <= 0) return;
      // Only retry if no file path and inline HTML is tiny/empty
      final hasFile = htmlPath != null && htmlPath.isNotEmpty;
      final len = html?.trim().length ?? 0;
      if (hasFile || len >= 50) return;
      if (_contentReloadRetries >= 2) return;
      _contentReloadRetries++;
      if (kDebugMode) {
        // ignore: avoid_print
        print('VIEWER:retry uid=$uid count=$_contentReloadRetries');
      }
      final delayMs = 700 * _contentReloadRetries;
      Future.delayed(Duration(milliseconds: delayMs), () {
        if (!mounted) return;
        // Ensure we are still on the same message
        if ((message.uid ?? -1) != uid) return;
        _loadCachedContent();
      });
    } catch (_) {}
  }

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

  // Parse sender from raw headers using enough_mail's MailAddress parser first.
  // Falls back to a minimal regex only if parsing fails, to avoid heavy custom logic.
  Map<String, String>? _parseSenderFromHeaders() {
    try {
      final raw =
          message.getHeaderValue('from') ?? message.getHeaderValue('reply-to');
      if (raw == null || raw.trim().isEmpty) return null;
      try {
        final addr = MailAddress.parse(raw);
        final displayName =
            (addr.personalName != null && addr.personalName!.trim().isNotEmpty)
                ? addr.personalName!.trim()
                : addr.email;
        return {'name': displayName, 'email': addr.email};
      } catch (_) {
        // Minimal best-effort extraction to avoid Unknown states
        final re = RegExp(r'([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})');
        final m = re.firstMatch(raw);
        final email = m != null ? m.group(1)!.trim() : 'unknown@example.com';
        String name = raw.trim();
        // Prefer quoted name or left side before '<'
        final quoted = RegExp(r'"([^"]+)"').firstMatch(raw)?.group(1)?.trim();
        if (quoted != null && quoted.isNotEmpty) {
          name = quoted;
        } else if (raw.contains('<')) {
          name = raw.split('<').first.trim();
        } else if (email != 'unknown@example.com' && raw.trim() == email) {
          name = email;
        }
        if (name.isEmpty) name = email;
        return {'name': name, 'email': email};
      }
    } catch (_) {
      return null;
    }
  }

  // Enhanced subject with proper fallback handling (enough_mail first)
  String get subject {
    final decodedSubject = message.decodeSubject();
    if (kDebugMode) {
      print('DEBUG: Subject - decodedSubject: $decodedSubject');
      print('DEBUG: Subject - envelope.subject: ${message.envelope?.subject}');
      print('DEBUG: Subject - headers: ${message.headers}');
    }

    if (decodedSubject == null || decodedSubject.trim().isEmpty) {
      // Try envelope subject as fallback
      final envSubject = message.envelope?.subject;
      if (envSubject != null && envSubject.trim().isNotEmpty) {
        return envSubject.trim();
      }
      // Last resort: raw Subject header if present
      final hdr = message.getHeaderValue('subject');
      if (hdr != null && hdr.trim().isNotEmpty) {
        return hdr.trim();
      }
      return 'No Subject';
    }
    return decodedSubject.trim();
  }

  // Enhanced sender name with proper fallback chain (prefer enough_mail, then header parse)
  String get name {
    // Try from field first
    if (message.from != null && message.from!.isNotEmpty) {
      final from = message.from!.first;
      if (from.personalName != null && from.personalName!.trim().isNotEmpty) {
        return from.personalName!.trim();
      }
      return from.email;
    }

    // Try sender field as fallback
    if (message.sender != null) {
      if (message.sender!.personalName != null &&
          message.sender!.personalName!.trim().isNotEmpty) {
        return message.sender!.personalName!.trim();
      }
      return message.sender!.email;
    }

    // Try fromEmail as fallback
    if (message.fromEmail != null && message.fromEmail!.trim().isNotEmpty) {
      return message.fromEmail!.trim();
    }

    // Last resort: parse from raw headers using enough_mail, then minimal regex
    final parsed = _parseSenderFromHeaders();
    if (parsed != null) return parsed['name'] ?? 'Unknown Sender';

    return 'Unknown Sender';
  }

  // Enhanced email address with proper fallback chain (prefer enough_mail, then header parse)
  String get email {
    // Try from field first
    if (message.from != null && message.from!.isNotEmpty) {
      return message.from!.first.email;
    }

    // Try sender field as fallback
    if (message.sender != null) {
      return message.sender!.email;
    }

    // Try fromEmail as fallback
    if (message.fromEmail != null && message.fromEmail!.trim().isNotEmpty) {
      return message.fromEmail!.trim();
    }

    // Last resort: parse from raw headers using enough_mail, then minimal regex
    final parsed = _parseSenderFromHeaders();
    if (parsed != null && (parsed['email']?.isNotEmpty ?? false))
      return parsed['email']!;

    return 'unknown@example.com';
  }

  // Enhanced date formatting with timezone awareness (enough_mail best practice)
  String get date {
    final messageDate = message.decodeDate();
    if (messageDate == null) {
      return "Date unknown";
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(
      messageDate.year,
      messageDate.month,
      messageDate.day,
    );

    // Professional date formatting based on recency
    if (messageDay == today) {
      // Today: show time only
      return DateFormat("h:mm a").format(messageDate);
    } else if (messageDay == today.subtract(const Duration(days: 1))) {
      // Yesterday
      return "Yesterday ${DateFormat("h:mm a").format(messageDate)}";
    } else if (now.difference(messageDate).inDays < 7) {
      // This week: show day name and time
      return DateFormat("EEE h:mm a").format(messageDate);
    } else if (messageDate.year == now.year) {
      // This year: show month, day, and time
      return DateFormat("MMM d, h:mm a").format(messageDate);
    } else {
      // Different year: show full date
      return DateFormat("MMM d, yyyy h:mm a").format(messageDate);
    }
  }

  // Enhanced detailed date for header display
  String get detailedDate {
    final messageDate = message.decodeDate();
    if (kDebugMode) {
      print('DEBUG: Date - decodeDate: $messageDate');
      print('DEBUG: Date - envelope.date: ${message.envelope?.date}');
      print('DEBUG: Date - headers date: ${message.getHeaderValue("date")}');
    }

    if (messageDate == null) {
      // Try envelope date as fallback
      if (message.envelope?.date != null) {
        return DateFormat(
          "EEE, MMM d, yyyy 'at' h:mm a",
        ).format(message.envelope!.date!);
      }

      // Try header date as fallback
      final headerDate = message.getHeaderValue("date");
      if (headerDate != null) {
        try {
          final parsedDate = DateTime.parse(headerDate);
          return DateFormat("EEE, MMM d, yyyy 'at' h:mm a").format(parsedDate);
        } catch (e) {
          if (kDebugMode) {
            print('DEBUG: Failed to parse header date: $headerDate');
          }
        }
      }

      return "Date unknown";
    }

    return DateFormat("EEE, MMM d, yyyy 'at' h:mm a").format(messageDate);
  }

  // Enhanced initials generation with better fallback handling
  String get initials {
    if (name.isEmpty || name == "Unknown Sender") return "?";

    final cleanName = name.trim();
    final nameParts = cleanName.split(RegExp(r'\s+'));

    if (nameParts.length > 1) {
      // First and last name initials
      return "${nameParts.first[0]}${nameParts.last[0]}".toUpperCase();
    } else if (cleanName.isNotEmpty) {
      // Single name or email - take first character
      return cleanName[0].toUpperCase();
    }

    return "?";
  }

  // Message status indicators (enough_mail best practice)
  bool get hasAttachments {
    return message.hasAttachments();
  }

  bool get isAnswered {
    return message.isAnswered;
  }

  bool get isForwarded {
    return message.isForwarded;
  }

  bool get isFlagged {
    return message.isFlagged;
  }

  bool get isSeen {
    return message.isSeen;
  }

  // Thread information
  int get threadLength {
    final threadSequence = message.threadSequence;
    return threadSequence != null ? threadSequence.toList().length : 0;
  }

  // Get color for avatar based on name
  Color get avatarColor {
    if (name.isEmpty) return AppTheme.primaryColor;

    // Use a consistent color based on the name
    final colorIndex =
        name.codeUnits.fold<int>(0, (prev, element) => prev + element) %
        AppTheme.colorPalette.length;
    return AppTheme.colorPalette[colorIndex];
  }

  final ValueNotifier<bool> showMeta = ValueNotifier<bool>(false);

  @override
  void didUpdateWidget(covariant ShowMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message ||
        oldWidget.mailbox != widget.mailbox) {
      message = widget.message;
      mailbox = widget.mailbox;
      _loadCachedContent();
      try {
        final ctrl = Get.find<MailBoxController>();
        _metaNotifier?.removeListener(_loadCachedContent);
        _metaNotifier = ctrl.getMessageMetaNotifier(mailbox, message);
        _metaNotifier!.addListener(_loadCachedContent);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppScaffold(
      backgroundColor: colorScheme.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: InbocAppBar(message: message, mailbox: mailbox),
      ),
      bottomNavigationBar: ViewMessageBottomNav(
        mailbox: mailbox,
        message: message,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Email header card
              Card(
                margin: const EdgeInsets.all(12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Enhanced subject with proper fallback handling
                      Text(
                        subject,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight:
                              isSeen ? FontWeight.w600 : FontWeight.w700,
                          height: 1.2,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Lightweight meta chips for a modern look
                      Wrap(
                        spacing: 6,
                        runSpacing: -6,
                        children: [
                          if (threadLength > 0)
                            Chip(
                              label: Text('${threadLength + 1} in thread'),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              labelStyle:
                                  Theme.of(context).textTheme.labelSmall,
                            ),
                          if (hasAttachments)
                            const Chip(
                              label: Text('Attachments'),
                              visualDensity: VisualDensity.compact,
                            ),
                          if (isFlagged)
                            const Chip(
                              label: Text('Flagged'),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Sender info with avatar
                      InkWell(
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadius,
                        ),
                        onTap: () {
                          showMeta.value = !showMeta.value;
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                backgroundColor: avatarColor,
                                radius: 24.0,
                                child: Text(
                                  initials,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Sender details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          detailedDate,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),

                                        // Message status indicators (enough_mail best practice)
                                        if (hasAttachments ||
                                            isAnswered ||
                                            isForwarded ||
                                            isFlagged ||
                                            threadLength > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 8,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (isFlagged)
                                                  Icon(
                                                    Icons.flag,
                                                    size: 14,
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.secondary,
                                                  ),
                                                if (hasAttachments)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 4,
                                                        ),
                                                    child: Icon(
                                                      Icons.attach_file,
                                                      size: 14,
                                                      color:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                    ),
                                                  ),
                                                if (isAnswered)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 4,
                                                        ),
                                                    child: Icon(
                                                      Icons.reply,
                                                      size: 14,
                                                      color:
                                                          Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                    ),
                                                  ),
                                                if (isForwarded)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 4,
                                                        ),
                                                    child: Icon(
                                                      Icons.forward,
                                                      size: 14,
                                                      color:
                                                          Theme.of(context)
                                                              .colorScheme
                                                              .secondary,
                                                    ),
                                                  ),
                                                if (threadLength > 0)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          left: 4,
                                                        ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .primary,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        threadLength.toString(),
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onPrimary,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      email,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Expand/collapse icon
                              ValueListenableBuilder(
                                valueListenable: showMeta,
                                builder:
                                    (context, isExpanded, _) => Icon(
                                      isExpanded
                                          ? Icons.keyboard_arrow_up
                                          : Icons.keyboard_arrow_down,
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Email metadata (recipients, cc, etc.)
                      MailMetaTile(message: message, isShow: showMeta),
                    ],
                  ),
                ),
              ),

              // Enhanced attachments (enterprise UX) above the body
              Card(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: AttachmentCarousel(
                    message: message,
                    mailbox: mailbox,
                    includeInline: false,
                    offlineOnly: false,
                    showHeader: true,
                  ),
                ),
              ),

              // Email body viewer (offline-first)
              Card(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: EnterpriseMessageViewer(
                    mimeMessage: message,
                    enableDarkMode:
                        Theme.of(context).brightness == Brightness.dark,
                    blockExternalImages: true,
                    textScale: MediaQuery.of(context).textScaler.scale(1.0),
                    initialHtml: _initialHtml,
                    initialHtmlPath: _initialHtmlPath,
                    preferInline:
                        Platform
                            .isIOS, // avoid iOS file:// CFNetwork issues by rendering inline
                  ),
                ),
              ),

              // Threaded conversation view
              ThreadViewer(message: message, mailbox: mailbox),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    try {
      _metaNotifier?.removeListener(_loadCachedContent);
    } catch (_) {}
    _metaNotifier = null;
    try {
      _renderPerf?.stop();
    } catch (_) {}
    try {
      _scrollPerf?.stop();
    } catch (_) {}
    super.dispose();
  }

  void _sendOpenTelemetryOnce() {
    if (_telemetrySent) return;
    try {
      if (_telemetryStart != null) {
        final ms = DateTime.now().difference(_telemetryStart!).inMilliseconds;
        final acct = MailService.instance.account.email;
        Telemetry.event(
          'message_open_ms',
          props: {
            'ms': ms,
            'mailbox_hash': Hashing.djb2(mailbox.encodedPath).toString(),
            'account_id_hash': Hashing.djb2(acct).toString(),
          },
        );
        _telemetrySent = true;
      }
    } catch (_) {}
  }
}
