import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/app/controllers/selection_controller.dart';
import 'package:wahda_bank/widgets/bottomnavs/selection_botttom_nav.dart';
import 'package:wahda_bank/widgets/mail_tile.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/utills/funtions.dart';
import 'package:wahda_bank/views/view/showmessage/show_message.dart';
import 'package:wahda_bank/views/compose/compose.dart';

class MailBoxView extends GetView<MailBoxController> {
  const MailBoxView({super.key, required this.mailBox});
  final Mailbox mailBox;

  @override
  Widget build(BuildContext context) {
    final selectionController = Get.find<SelectionController>();
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return PopScope(
      onPopInvoked: (didPop) => selectionController.selected.clear(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            mailBox.name.toLowerCase().tr,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: isDarkMode
              ? Colors.black.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.9),
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await controller.refreshMailbox(mailBox);
          },
          color: theme.colorScheme.primary,
          backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDarkMode
                    ? [Colors.black, Colors.grey.shade900]
                    : [Colors.grey.shade50, Colors.white],
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: OptimizedEmailList(
                    mailBox: mailBox,
                    controller: controller,
                    theme: theme,
                    isDarkMode: isDarkMode,
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Obx(() {
          return selectionController.selected.isNotEmpty
              ? SelectionBottomNav(box: mailBox)
              : const SizedBox.shrink();
        }),
      ),
    );
  }
}

class OptimizedEmailList extends StatefulWidget {
  final Mailbox mailBox;
  final MailBoxController controller;
  final ThemeData theme;
  final bool isDarkMode;

  const OptimizedEmailList({
    super.key,
    required this.mailBox,
    required this.controller,
    required this.theme,
    required this.isDarkMode,
  });

  @override
  State<OptimizedEmailList> createState() => _OptimizedEmailListState();
}

class _OptimizedEmailListState extends State<OptimizedEmailList> {
  final ScrollController _scrollController = ScrollController();
  final Map<DateTime, List<MimeMessage>> _groupedMessages = {};
  final List<DateTime> _dateKeys = [];
  bool _isLoadingMore = false;
  int _currentPage = 0;
  static const int _pageSize = 50; // Increased from 20 to match controller

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Trigger loading when user is 300 pixels from the bottom
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      _loadMoreMessages();
    }
  }

  void _refreshMessages() {
    final messages = widget.controller.boxMails;
    _processMessages(messages);
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore) return;
    
    setState(() {
      _isLoadingMore = true;
    });

    try {
      await widget.controller.loadMoreEmails(widget.mailBox, _currentPage + 1);
      _currentPage++;
      
      final messages = widget.controller.boxMails;
      _processMessages(messages);
    } catch (e) {
      // Handle error
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _processMessages(List<MimeMessage> messages) {
    _groupedMessages.clear();
    _dateKeys.clear();

    for (final message in messages) {
      // Use the enhanced date parsing from mail tile
      DateTime? messageDate;
      
      // Try multiple date sources in order of preference
      try {
        messageDate = message.decodeDate();
      } catch (e) {
        // Fallback to envelope date
        messageDate = message.envelope?.date;
      }
      
      // Final fallback to current date if all else fails
      final date = messageDate ?? DateTime.now();
      final dateKey = DateTime(date.year, date.month, date.day);
      
      if (!_groupedMessages.containsKey(dateKey)) {
        _groupedMessages[dateKey] = [];
        _dateKeys.add(dateKey);
      }
      _groupedMessages[dateKey]!.add(message);
    }

    // Sort dates in descending order (newest first)
    _dateKeys.sort((a, b) => b.compareTo(a));
    
    // Sort messages within each date group by time (newest first)
    for (final dateKey in _dateKeys) {
      _groupedMessages[dateKey]!.sort((a, b) {
        final dateA = a.decodeDate() ?? a.envelope?.date ?? DateTime.now();
        final dateB = b.decodeDate() ?? b.envelope?.date ?? DateTime.now();
        return dateB.compareTo(dateA);
      });
    }
    
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<MimeMessage>>(
      valueListenable: widget.controller.mailboxStorage[widget.mailBox]!.dataNotifier,
      builder: (context, List<MimeMessage> messages, _) {
        if (messages.isEmpty && !widget.controller.isBoxBusy()) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Whoops! Box is empty',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => widget.controller.loadEmailsForBox(widget.mailBox),
                  child: Text('try_again'.tr),
                ),
              ],
            ),
          );
        }

        // Update processed messages when data changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _processMessages(messages);
        });

        return CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= _dateKeys.length) {
                    return _isLoadingMore
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : const SizedBox.shrink();
                  }

                  final dateKey = _dateKeys[index];
                  final messagesForDate = _groupedMessages[dateKey] ?? [];

                  return OptimizedDateGroup(
                    date: dateKey,
                    messages: messagesForDate,
                    mailBox: widget.mailBox,
                    theme: widget.theme,
                    isDarkMode: widget.isDarkMode,
                  );
                },
                childCount: _dateKeys.length + (_isLoadingMore ? 1 : 0),
              ),
            ),
          ],
        );
      },
    );
  }
}

class OptimizedDateGroup extends StatelessWidget {
  final DateTime date;
  final List<MimeMessage> messages;
  final Mailbox mailBox;
  final ThemeData theme;
  final bool isDarkMode;

  const OptimizedDateGroup({
    super.key,
    required this.date,
    required this.messages,
    required this.mailBox,
    required this.theme,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _formatDate(date),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final message = messages[index];
            return OptimizedMailTile(
              message: message,
              mailBox: mailBox,
              onTap: () {
                // CRITICAL FIX: Use safe navigation method with validation
                final mailboxController = Get.find<MailBoxController>();
                
                print('=== MAILBOX VIEW EMAIL TAP DEBUG ===');
                print('MailBoxView.dart onTap called!');
                print('Subject: ${message.decodeSubject()}');
                print('Current Mailbox: ${mailBox.name}');
                print('Using safe navigation method');
                print('====================================');
                
                // Use the new safe navigation method from the controller
                mailboxController.safeNavigateToMessage(message, mailBox);
              },
            );
          },
          itemCount: messages.length,
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);
    final weekAgo = today.subtract(const Duration(days: 7));

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else if (dateOnly.isAfter(weekAgo)) {
      // This week - show day name
      const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return days[date.weekday - 1];
    } else if (date.year == now.year) {
      // This year - show month and day
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}';
    } else {
      // Different year - show full date
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }
}

class OptimizedMailTile extends StatelessWidget {
  final MimeMessage message;
  final Mailbox mailBox;
  final VoidCallback onTap;

  const OptimizedMailTile({
    super.key,
    required this.message,
    required this.mailBox,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MailTile(
      message: message,
      mailBox: mailBox,
      onTap: onTap,
    );
  }
}

