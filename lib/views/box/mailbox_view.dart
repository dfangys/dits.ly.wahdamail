import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/utills/funtions.dart';
import '../../app/controllers/mailbox_controller.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../app/controllers/selection_controller.dart';
import '../../widgets/bottomnavs/selection_botttom_nav.dart';
import '../../widgets/empty_box.dart';
import '../../widgets/mail_tile.dart';
import '../view/showmessage/show_message.dart';

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
              ? Colors.black.withValues(alpha : 0.7)
              : Colors.white.withValues(alpha : 0.9),
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
                ],
              ),
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
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadInitialData() async {
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

    final sortedMessages = messages.sorted((a, b) {
      final dateA = a.decodeDate() ?? DateTime(1970);
      final dateB = b.decodeDate() ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });

    final grouped = groupBy<MimeMessage, DateTime>(
      sortedMessages,
      (m) => filterDate(m.decodeDate() ?? DateTime.now()),
    );

    _groupedMessages.addAll(grouped);
    _dateKeys.addAll(grouped.keys.toList()..sort((a, b) => b.compareTo(a)));

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<MimeMessage>>(
      valueListenable: widget.controller.mailboxStorage[widget.mailBox]!.dataNotifier,
      builder: (context, List<MimeMessage> messages, _) {
        if (messages.isEmpty && !widget.controller.isBoxBusy()) {
          return TAnimationLoaderWidget(
            text: 'Whoops! Box is empty',
            animation: 'assets/lottie/empty.json',
            showAction: true,
            actionText: 'try_again'.tr,
            onActionPressed: () => widget.controller.loadEmailsForBox(widget.mailBox),
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
        // Date header with modern styling
        Container(
          margin: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha : 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  timeago.format(messages.first.decodeDate() ?? DateTime.now()),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha : 0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Optimized message list
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: messages.length,
          itemBuilder: (context, messageIndex) {
            final message = messages[messageIndex];
            return OptimizedMailTile(
              key: ValueKey(message.uid ?? message.sequenceId),
              message: message,
              mailBox: mailBox,
              onTap: () {
                Get.to(
                  () => ShowMessage(
                    message: message,
                    mailbox: mailBox,
                  ),
                  transition: Transition.rightToLeft,
                  duration: const Duration(milliseconds: 300),
                );
              },
            );
          },
        ),
      ],
    );
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

