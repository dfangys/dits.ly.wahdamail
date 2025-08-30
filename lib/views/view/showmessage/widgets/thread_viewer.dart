import 'package:flutter/material.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import '../../../../services/mail_service.dart';
import '../../../../services/message_content_store.dart';
import '../../../compose/redesigned_compose_screen.dart';

class ThreadViewer extends StatefulWidget {
  const ThreadViewer({super.key, required this.message, required this.mailbox});
  final MimeMessage message;
  final Mailbox mailbox;

  @override
  State<ThreadViewer> createState() => _ThreadViewerState();
}

class _ThreadViewerState extends State<ThreadViewer> {
  bool _loading = true;
  String? _error;
  List<MimeMessage> _thread = [];
  bool _oldestFirst = true;

  // Track expanded state and meta notifiers for live updates
  final Set<String> _expanded = <String>{};
  final Map<String, ValueNotifier<int>> _meta = {};

  @override
  void initState() {
    super.initState();
    _loadThread();
  }

  String _idKey(MimeMessage m) =>
      (m.uid != null) ? 'uid:${m.uid}' : (m.sequenceId != null ? 'seq:${m.sequenceId}' : 'hash:${m.hashCode}');

  void _attachMetaNotifiers() {
    try {
      final ctrl = Get.find<MailBoxController>();
      // Clean up previous listeners
      _meta.forEach((_, n) {
        try { n.removeListener(_onAnyMetaChange); } catch (_) {}
      });
      _meta.clear();

      for (final m in _thread) {
        try {
          final n = ctrl.getMessageMetaNotifier(widget.mailbox, m);
          n.addListener(_onAnyMetaChange);
          _meta[_idKey(m)] = n;
        } catch (_) {}
      }
    } catch (_) {}
  }

  void _onAnyMetaChange() {
    if (!mounted) return;
    setState(() {}); // reflect preview/x-ready updates without flicker
  }

  Future<void> _loadThread() async {
    try {
      setState(() { _loading = true; _error = null; });
      final seq = widget.message.threadSequence;
      if (seq == null || seq.isEmpty) {
        // Fallback: derive using headers/subject within current mailbox window
        final ctrl = Get.find<MailBoxController>();
        final list = List<MimeMessage>.from(ctrl.emails[widget.mailbox] ?? const <MimeMessage>[]);
        String norm(String? s) {
          if (s == null) return '';
          var t = s.trim();
          final rx = RegExp(r'^(?:(re|fw|fwd|aw|wg)\s*:\s*)+', caseSensitive: false);
          t = t.replaceAll(rx, '').trim();
          return t.toLowerCase();
        }
        String keyFor(MimeMessage m) {
          final refs = m.getHeaderValue('references');
          if (refs != null && refs.isNotEmpty) {
            final ids = RegExp(r'<[^>]+>').allMatches(refs).map((mm) => mm.group(0)!).toList();
            if (ids.isNotEmpty) return ids.first;
          }
          final irt = m.getHeaderValue('in-reply-to');
          if (irt != null && irt.isNotEmpty) {
            final id = RegExp(r'<[^>]+>').firstMatch(irt)?.group(0);
            if (id != null) return id;
          }
          return 'subj::'+norm(m.decodeSubject() ?? m.envelope?.subject);
        }
        final targetKey = keyFor(widget.message);
        final others = list.where((m) {
          if ((widget.message.uid != null && m.uid == widget.message.uid) || (widget.message.sequenceId != null && m.sequenceId == widget.message.sequenceId)) {
            return false;
          }
          return keyFor(m) == targetKey;
        }).toList();
        _sort(others);
        setState(() { _thread = others; _loading = false; });
        _attachMetaNotifiers();
        return;
      }

      final mail = MailService.instance;
      if (!mail.client.isConnected) {
        try { await mail.connect().timeout(const Duration(seconds: 8)); } catch (_) {}
      }
      if (mail.client.selectedMailbox?.encodedPath != widget.mailbox.encodedPath) {
        try { await mail.client.selectMailbox(widget.mailbox).timeout(const Duration(seconds: 8)); } catch (_) {}
      }

      final msgs = await mail.client.fetchMessageSequence(
        seq,
        fetchPreference: FetchPreference.envelope,
      ).timeout(const Duration(seconds: 20), onTimeout: () => <MimeMessage>[]);

      // Remove the current message and sort
      final currentUid = widget.message.uid;
      final currentSeq = widget.message.sequenceId;
      final filtered = msgs.where((m) => (currentUid != null && m.uid != currentUid) || (currentSeq != null && m.sequenceId != currentSeq)).toList();
      _sort(filtered);

      setState(() { _thread = filtered; _loading = false; });
      _attachMetaNotifiers();
    } catch (e) {
      setState(() { _error = 'Failed to load thread: $e'; _loading = false; });
    }
  }

  void _sort(List<MimeMessage> list) {
    list.sort((a, b) {
      final da = a.decodeDate();
      final db = b.decodeDate();
      final cmp = () {
        if (da == null && db == null) return 0;
        if (da == null) return -1;
        if (db == null) return 1;
        return da.compareTo(db);
      }();
      return _oldestFirst ? cmp : -cmp;
    });
  }

  @override
  void dispose() {
    _meta.forEach((_, n) {
      try { n.removeListener(_onAnyMetaChange); } catch (_) {}
    });
    _meta.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.forum_outlined, size: 18),
              const SizedBox(width: 6),
              Text('Conversation', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              IconButton(onPressed: _loadThread, icon: const Icon(Icons.refresh)),
            ]),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
          ],
        ),
      );
    }

    if (_thread.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius)),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(children: [
                  const Icon(Icons.forum_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text('Conversation', style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  Text(_oldestFirst ? 'Oldest → Newest' : 'Newest → Oldest', style: Theme.of(context).textTheme.labelSmall),
                  IconButton(
                    tooltip: 'Toggle order',
                    icon: const Icon(Icons.swap_vert),
                    onPressed: () {
                      setState(() {
                        _oldestFirst = !_oldestFirst;
                        _sort(_thread);
                      });
                    },
                  ),
                ]),
              ),
              const Divider(height: 1),
              ..._thread.map((m) => _ConversationItem(
                    key: ValueKey(_idKey(m)),
                    mailbox: widget.mailbox,
                    message: m,
                    expanded: _expanded.contains(_idKey(m)),
                    onToggle: () {
                      final k = _idKey(m);
                      setState(() {
                        if (_expanded.contains(k)) {
                          _expanded.remove(k);
                        } else {
                          _expanded.add(k);
                        }
                      });
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationItem extends StatefulWidget {
  const _ConversationItem({super.key, required this.mailbox, required this.message, required this.expanded, required this.onToggle});
  final Mailbox mailbox;
  final MimeMessage message;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  State<_ConversationItem> createState() => _ConversationItemState();
}

class _ConversationItemState extends State<_ConversationItem> {
  bool _loadingBody = false;
  String? _initialHtml;
  String? _initialHtmlPath;

  @override
  void initState() {
    super.initState();
    if (widget.expanded) _ensureBody();
  }

  @override
  void didUpdateWidget(covariant _ConversationItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded && !oldWidget.expanded) {
      _ensureBody();
    }
  }

  Future<void> _ensureBody() async {
    if (_loadingBody) return;
    setState(() => _loadingBody = true);
    try {
      final msg = widget.message;
      final uid = msg.uid ?? -1;
      final store = MessageContentStore.instance;
      final accountEmail = MailService.instance.account.email;
      final mailboxPath = widget.mailbox.encodedPath.isNotEmpty ? widget.mailbox.encodedPath : widget.mailbox.path;
      final uidValidity = widget.mailbox.uidValidity ?? 0;

      // Try cached first
      CachedMessageContent? cached;
      if (uid > 0) {
        try {
          cached = await store.getContent(
            accountEmail: accountEmail,
            mailboxPath: mailboxPath,
            uidValidity: uidValidity,
            uid: uid,
          );
        } catch (_) {}
      }

      String? html = cached?.htmlSanitizedBlocked;
      String? htmlPath = cached?.htmlFilePath;

      if ((html == null || html.trim().isEmpty) && (htmlPath == null || htmlPath.isEmpty)) {
        try {
          // Prefetch body in the background
          await Get.find<MailBoxController>().prefetchMessageContent(widget.mailbox, msg, quiet: true);
          // Re-check cache
          if (uid > 0) {
            cached = await store.getContent(
              accountEmail: accountEmail,
              mailboxPath: mailboxPath,
              uidValidity: uidValidity,
              uid: uid,
            );
            html = cached?.htmlSanitizedBlocked;
            htmlPath = cached?.htmlFilePath;
          }
        } catch (_) {}
      }

      setState(() {
        _initialHtml = html;
        _initialHtmlPath = htmlPath;
      });
    } finally {
      if (mounted) setState(() => _loadingBody = false);
    }
  }

  String get _subject {
    final s = widget.message.decodeSubject();
    return (s == null || s.trim().isEmpty) ? (widget.message.envelope?.subject ?? 'No Subject') : s.trim();
  }

  String get _sender {
    if (widget.message.from != null && widget.message.from!.isNotEmpty) {
      final f = widget.message.from!.first;
      return f.personalName?.trim().isNotEmpty == true ? f.personalName! : f.email;
    }
    return widget.message.fromEmail ?? 'unknown@sender';
  }

  String get _preview {
    final p = widget.message.getHeaderValue('x-preview');
    if (p != null && p.trim().isNotEmpty) return p;
    final t = widget.message.decodeTextPlainPart();
    if (t != null && t.trim().isNotEmpty) return t.replaceAll(RegExp(r'\s+'), ' ').trim();
    final html = widget.message.decodeTextHtmlPart();
    if (html != null && html.trim().isNotEmpty) {
      final stripped = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
      return stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    return '';
  }

  String get _date {
    final d = widget.message.decodeDate() ?? widget.message.envelope?.date;
    if (d == null) return '';
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.month}/${d.day}/${d.year}';
  }

  void _reply(String type) {
    Get.to(() => const RedesignedComposeScreen(), arguments: {
      'message': widget.message,
      'type': type,
    });
  }

  Future<void> _delete() async {
    try {
      final ctrl = Get.find<MailBoxController>();
      await ctrl.deleteMails([widget.message], widget.mailbox);
      // Let parent refresh by popping expansion, UI will update via controller lists
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                    child: Text(_sender.isNotEmpty ? _sender[0].toUpperCase() : '?', style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(_sender, style: const TextStyle(fontWeight: FontWeight.w600))),
                            Text(_date, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(_subject, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(widget.expanded ? Icons.expand_less : Icons.expand_more),
                    onPressed: widget.onToggle,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (!widget.expanded)
                Text(_preview, maxLines: 3, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
              if (widget.expanded) ...[
                if (_loadingBody)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                else
                  _ConversationBody(
                    mailbox: widget.mailbox,
                    message: widget.message,
                    initialHtml: _initialHtml,
                    initialHtmlPath: _initialHtmlPath,
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(onPressed: () => _reply('reply'), icon: const Icon(Icons.reply_rounded), label: const Text('Reply')),
                    const SizedBox(width: 8),
                    TextButton.icon(onPressed: () => _reply('reply_all'), icon: const Icon(Icons.reply_all_rounded), label: const Text('Reply All')),
                    const SizedBox(width: 8),
                    TextButton.icon(onPressed: () => _reply('forward'), icon: const Icon(Icons.forward_rounded), label: const Text('Forward')),
                    const Spacer(),
                    IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded), color: Colors.redAccent),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationBody extends StatelessWidget {
  const _ConversationBody({required this.mailbox, required this.message, this.initialHtml, this.initialHtmlPath});
  final Mailbox mailbox;
  final MimeMessage message;
  final String? initialHtml;
  final String? initialHtmlPath;

  @override
  Widget build(BuildContext context) {
    // Render lightweight HTML or show a small notice if none available yet.
    if ((initialHtmlPath == null || initialHtmlPath!.isEmpty) && (initialHtml == null || initialHtml!.trim().isEmpty)) {
      return Text(
        'Loading content…',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondaryColor),
      );
    }

    // Keep the body minimal to avoid heavy nested webviews across many items; show a short excerpt.
    final preview = (initialHtml ?? '').replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final snippet = preview.isNotEmpty ? (preview.length > 400 ? preview.substring(0, 400) + '…' : preview) : 'Content ready';

    return Text(snippet, style: Theme.of(context).textTheme.bodyMedium);
  }
}

