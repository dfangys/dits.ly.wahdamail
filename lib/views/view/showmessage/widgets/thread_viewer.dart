import 'package:flutter/material.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import '../../../../services/mail_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadThread();
  }

  Future<void> _loadThread() async {
    try {
      setState(() { _loading = true; _error = null; });
      final seq = widget.message.threadSequence;
      if (seq == null || seq.isEmpty) {
        // Local fallback: group by References/In-Reply-To/normalized subject within current mailbox list
        try {
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
          final thread = list.where((m) {
            if ((widget.message.uid != null && m.uid == widget.message.uid) || (widget.message.sequenceId != null && m.sequenceId == widget.message.sequenceId)) {
              return false; // exclude current message
            }
            return keyFor(m) == targetKey;
          }).toList();
          // Sort by date ascending
          thread.sort((a, b) {
            final da = a.decodeDate();
            final db = b.decodeDate();
            if (da == null && db == null) return 0;
            if (da == null) return -1;
            if (db == null) return 1;
            return da.compareTo(db);
          });
          setState(() { _thread = thread; _loading = false; });
        } catch (e) {
          setState(() { _thread = []; _loading = false; });
        }
        return;
      }

      final mail = MailService.instance;
      if (!mail.client.isConnected) {
        await mail.connect().timeout(const Duration(seconds: 8));
      }
      if (mail.client.selectedMailbox?.encodedPath != widget.mailbox.encodedPath) {
        await mail.client.selectMailbox(widget.mailbox).timeout(const Duration(seconds: 8));
      }

      final msgs = await mail.client.fetchMessageSequence(
        seq,
        fetchPreference: FetchPreference.envelope,
      ).timeout(const Duration(seconds: 20));

      // Sort by date ascending (oldest first)
      msgs.sort((a, b) {
        final da = a.decodeDate();
        final db = b.decodeDate();
        if (da == null && db == null) return 0;
        if (da == null) return -1;
        if (db == null) return 1;
        return da.compareTo(db);
      });

      // Filter out the current message by UID/sequenceId
      final currentUid = widget.message.uid;
      final currentSeq = widget.message.sequenceId;
      final filtered = msgs.where((m) => (currentUid != null && m.uid != currentUid) || (currentSeq != null && m.sequenceId != currentSeq)).toList();

      setState(() { _thread = filtered; _loading = false; });
    } catch (e) {
      setState(() { _error = 'Failed to load thread: $e'; _loading = false; });
    }
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
            ]),
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
            const SizedBox(height: 8),
            ElevatedButton.icon(onPressed: _loadThread, icon: const Icon(Icons.refresh), label: const Text('Retry')),
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
                ]),
              ),
              const Divider(height: 1),
              ..._thread.take(20).map((m) => _ThreadTile(message: m, mailbox: widget.mailbox)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.message, required this.mailbox});
  final MimeMessage message;
  final Mailbox mailbox;

  String _subject() {
    final s = message.decodeSubject();
    return (s == null || s.trim().isEmpty) ? (message.envelope?.subject ?? 'No Subject') : s.trim();
  }

  String _sender() {
    if (message.from != null && message.from!.isNotEmpty) {
      final m = message.from!.first;
      return m.personalName?.trim().isNotEmpty == true ? m.personalName! : m.email;
    }
    return message.fromEmail ?? 'unknown@sender';
  }

  String _preview() {
    final p = message.getHeaderValue('x-preview');
    if (p != null && p.trim().isNotEmpty) return p;
    final t = message.decodeTextPlainPart();
    if (t != null && t.trim().isNotEmpty) return t.replaceAll(RegExp(r'\s+'), ' ').trim();
    final html = message.decodeTextHtmlPart();
    if (html != null && html.trim().isNotEmpty) {
      final stripped = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
      return stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
    }
    return '';
  }

  String _date() {
    final d = message.decodeDate() ?? message.envelope?.date;
    if (d == null) return '';
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '${d.month}/${d.day}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<MailBoxController>();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
        child: Text(_sender().isNotEmpty ? _sender()[0].toUpperCase() : '?', style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
      ),
      title: Text(_subject(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text('${_sender()}  •  ${_preview()}', maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(_date(), style: Theme.of(context).textTheme.bodySmall),
      onTap: () => ctrl.safeNavigateToMessage(message, mailbox),
    );
  }
}

