import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/views/view/showmessage/show_message.dart';

class ShowMessagePager extends StatefulWidget {
  const ShowMessagePager({super.key, required this.mailbox, required this.initialMessage});

  final Mailbox mailbox;
  final MimeMessage initialMessage;

  @override
  State<ShowMessagePager> createState() => _ShowMessagePagerState();
}

class _ShowMessagePagerState extends State<ShowMessagePager> {
  late PageController _pageController;
  int _currentIndex = 0;
  late MailBoxController _mailBoxController;

  @override
  void initState() {
    super.initState();
    _mailBoxController = Get.find<MailBoxController>();
    // Compute index from filtered/sorted visible list
    final visible = _visibleMessages();
    _currentIndex = _indexOfMessage(visible, widget.initialMessage);
    _pageController = PageController(initialPage: _currentIndex);
  }

  List<MimeMessage> _visibleMessages() {
    final all = List<MimeMessage>.from(_mailBoxController.emails[widget.mailbox] ?? const <MimeMessage>[]);
    // Filter only ready messages and sort newest-first similar to inbox list
    final ready = all.where((m) => m.getHeaderValue('x-ready') == '1').toList();
    ready.sort((a, b) {
      final ua = a.uid ?? a.sequenceId ?? 0;
      final ub = b.uid ?? b.sequenceId ?? 0;
      if (ua != ub) return ub.compareTo(ua);
      final da = a.decodeDate();
      final db = b.decodeDate();
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    // Always include the initially opened message even if it's not yet marked ready
    final target = widget.initialMessage;
    final exists = ready.indexWhere((m) =>
      (target.uid != null && m.uid == target.uid) ||
      (target.sequenceId != null && m.sequenceId == target.sequenceId)
    ) != -1;
    if (!exists) {
      ready.insert(0, target);
    }
    return ready;
  }

  int _indexOfMessage(List<MimeMessage> list, MimeMessage message) {
    int idx = list.indexWhere((m) =>
        (message.uid != null && m.uid == message.uid) ||
        (message.sequenceId != null && m.sequenceId == message.sequenceId));
    if (idx < 0) idx = 0;
    return idx;
  }


  @override
  Widget build(BuildContext context) {
    final messages = _visibleMessages();

    if (messages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Message')),
        body: const Center(child: Text('No messages available')),
      );
    }

    return Scaffold(
      // No outer AppBar: rely on inner ShowMessage AppBar for consistent look
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: const ClampingScrollPhysics(),
            onPageChanged: (i) {
              setState(() => _currentIndex = i);
              try {
                final messages = _visibleMessages();
                if (i >= 0 && i < messages.length) {
                  _mailBoxController.prefetchMessageContent(widget.mailbox, messages[i], quiet: true);
                }
                // Prefetch neighbors opportunistically
                final next = i + 1;
                if (next >= 0 && next < messages.length) {
                  _mailBoxController.prefetchMessageContent(widget.mailbox, messages[next], quiet: true);
                }
                final prev = i - 1;
                if (prev >= 0 && prev < messages.length) {
                  _mailBoxController.prefetchMessageContent(widget.mailbox, messages[prev], quiet: true);
                }
              } catch (_) {}
            },
            itemCount: messages.length,
            itemBuilder: (ctx, i) {
              final m = messages[i];
              final key = ValueKey('msg-${m.uid ?? m.sequenceId ?? i}');
              return ShowMessage(key: key, message: m, mailbox: widget.mailbox);
            },
          ),

          // Page indicator
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentIndex + 1}/${messages.length}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}


