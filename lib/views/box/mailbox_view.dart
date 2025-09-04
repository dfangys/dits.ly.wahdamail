import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/app/controllers/selection_controller.dart';
import 'package:wahda_bank/widgets/bottomnavs/selection_botttom_nav.dart';
import 'package:wahda_bank/widgets/mail_tile.dart';
import 'package:wahda_bank/views/box/enhanced_mailbox_view.dart';
import 'package:wahda_bank/shared/di/injection.dart';
import 'package:wahda_bank/features/messaging/presentation/mailbox_view_model.dart';
import 'package:wahda_bank/design_system/components/app_scaffold.dart';
import 'package:wahda_bank/design_system/components/empty_state.dart';

class MailBoxView extends GetView<MailBoxController> {
  const MailBoxView({
    super.key,
    required this.mailbox,
    this.isDarkMode = false,
  });
  final Mailbox mailbox;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final selectionController = Get.find<SelectionController>();
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    // P12.2: Obtain MailboxViewModel via DI and kick off prefetch orchestration (no UI change)
    final mailboxVm = Get.put<MailboxViewModel>(getIt<MailboxViewModel>());
    mailboxVm.prefetchOnMailboxOpen(folderId: mailbox.path);

    return PopScope(
      onPopInvokedWithResult:
          (didPop, result) => selectionController.selected.clear(),
      child: FocusTraversalGroup(
        policy: ReadingOrderTraversalPolicy(),
        child: AppScaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            mailbox.name.toLowerCase().tr,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: theme.colorScheme.surface.withValues(alpha: isDarkMode ? 0.7 : 0.9),
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        // Single source of pull-to-refresh: handled inside EnhancedMailboxView
        body: EnhancedMailboxView(
          mailbox: mailbox,
          theme: theme,
          isDarkMode: isDarkMode,
        ),
        bottomNavigationBar: Obx(() {
          return selectionController.selected.isNotEmpty
              ? SelectionBottomNav(box: mailbox)
              : const SizedBox.shrink();
        }),
      ),
      ),
    );
  }
}

class OptimizedEmailList extends StatefulWidget {
  final Mailbox mailbox;
  final MailBoxController controller;
  final ThemeData theme;
  final bool isDarkMode;

  const OptimizedEmailList({
    super.key,
    required this.mailbox,
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
  // Performance optimization variables
  List<MimeMessage>? _sortedMessages;
  int _lastProcessedCount = 0;

  // Duplicate prevention with Set-based UID tracking
  final Set<int> _processedUIDs = <int>{};
  bool _allMessagesLoaded = false;

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
    // Enhanced scroll detection with improved performance and user feedback
    if (!_scrollController.hasClients || _isLoadingMore || _allMessagesLoaded)
      return;

    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;

    // ENHANCED: More responsive scroll loading with better thresholds
    // Trigger loading when user is within 600px of bottom (reduced from 800px for faster loading)
    // But not at absolute bottom to prevent infinite loops
    if (currentScroll >= maxScroll - 600 &&
        currentScroll <
            maxScroll - 50 && // Smaller buffer for more responsive loading
        maxScroll > 0) {
      // ENHANCED: Add haptic feedback for better user experience
      try {
        HapticFeedback.selectionClick();
      } catch (e) {
        // Ignore haptic feedback errors on unsupported devices
      }

      _loadMoreMessages();
    }
  }

  void _loadMoreMessages() async {
    if (_isLoadingMore || !mounted || _allMessagesLoaded) return;

    final totalMessages = widget.controller.boxMails.length;
    final currentlyDisplayed =
        _processedUIDs.length; // Use processed UIDs count for accuracy

    // Check if we've reached the end based on mailbox message count
    final mailboxMessageCount = widget.mailbox.messagesExists;
    if (currentlyDisplayed >= mailboxMessageCount && mailboxMessageCount > 0) {
      _allMessagesLoaded = true;
      return;
    }

    // Set loading state once
    setState(() {
      _isLoadingMore = true;
    });

    try {
      // Check if we have more messages to display
      if (currentlyDisplayed >= totalMessages) {
        // Try to load more from server
        final previousCount = totalMessages;
        await widget.controller.loadMoreEmails(
          widget.mailbox,
          _currentPage + 1,
        );

        // Check if new messages were actually loaded
        final newTotalMessages = widget.controller.boxMails.length;
        if (newTotalMessages > previousCount) {
          _currentPage++; // Increment page only after successful load

          // Refresh the display with new messages
          final allMessages = widget.controller.boxMails;
          _processMessages(allMessages);
        } else {
          // No new messages loaded, mark as complete
          _allMessagesLoaded = true;
        }
      } else {
        // We have more messages locally, just display them
        // Reduced delay for better performance
        await Future.delayed(const Duration(milliseconds: 50));

        final allMessages = widget.controller.boxMails;
        _processMessages(allMessages);
      }
    } catch (e) {
      // Handle error silently or show user feedback
      debugPrint('Error loading more emails: $e');
      // Don't mark as loaded on error, allow retry
    } finally {
      // Clear loading state once
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _processMessages(List<MimeMessage> messages) {
    // Skip processing if messages haven't changed to avoid unnecessary work
    if (messages.length == _lastProcessedCount && _groupedMessages.isNotEmpty) {
      return;
    }

    // CRITICAL FIX: Process ALL messages, not just new unique ones
    // Filter out duplicate messages using UID-based Set checking
    final allUniqueMessages = <MimeMessage>[];
    final allUIDs = <int>{};

    for (final message in messages) {
      final uid = message.uid ?? message.sequenceId ?? 0;
      if (uid > 0 && !allUIDs.contains(uid)) {
        allUniqueMessages.add(message);
        allUIDs.add(uid);
      }
    }

    // If no messages, clear everything
    if (allUniqueMessages.isEmpty) {
      _groupedMessages.clear();
      _dateKeys.clear();
      _processedUIDs.clear();
      _lastProcessedCount = 0;
      if (mounted) setState(() {});
      return;
    }

    // Update processed UIDs and count
    _processedUIDs.clear();
    _processedUIDs.addAll(allUIDs);
    _lastProcessedCount = messages.length;

    // Clear and rebuild with ALL unique messages
    _groupedMessages.clear();
    _dateKeys.clear();

    // Sort ALL unique messages and cache the result
    _sortedMessages = List<MimeMessage>.from(allUniqueMessages);
    _sortedMessages!.sort((a, b) {
      final dateA = _getMessageDate(a);
      final dateB = _getMessageDate(b);
      return dateB.compareTo(dateA); // Newest first
    });

    // Group ALL messages by date efficiently
    for (final message in _sortedMessages!) {
      final date = _getMessageDate(message);
      final dateKey = DateTime(date.year, date.month, date.day);

      if (!_groupedMessages.containsKey(dateKey)) {
        _groupedMessages[dateKey] = [];
        _dateKeys.add(dateKey);
      }
      _groupedMessages[dateKey]!.add(message);
    }

    // Sort date keys once
    _dateKeys.sort((a, b) => b.compareTo(a)); // Newest dates first

    if (mounted) {
      setState(() {});
    }
  }

  DateTime _getMessageDate(MimeMessage message) {
    // Enhanced date extraction with multiple fallbacks
    DateTime? messageDate;

    try {
      // Primary: Use decodeDate() method
      messageDate = message.decodeDate();
      if (messageDate != null) return messageDate;
    } catch (e) {
      // Continue to next fallback
    }

    try {
      // Secondary: Use envelope date
      messageDate = message.envelope?.date;
      if (messageDate != null) return messageDate;
    } catch (e) {
      // Continue to next fallback
    }

    try {
      // Tertiary: Parse date from headers
      final dateHeader = message.getHeaderValue('date');
      if (dateHeader != null) {
        messageDate = DateTime.tryParse(dateHeader);
        if (messageDate != null) return messageDate;
      }
    } catch (e) {
      // Continue to final fallback
    }

    // Final fallback: Use current time (should rarely happen)
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<MimeMessage>>(
      valueListenable:
          widget.controller.mailboxStorage[widget.mailbox]!.dataNotifier,
      builder: (context, List<MimeMessage> messages, _) {
        if (messages.isEmpty && !widget.controller.isBoxBusy()) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                EmptyState(
                  title: 'Whoops! Box is empty',
                  message: null,
                  icon: Icons.inbox_outlined,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed:
                      () => widget.controller.loadEmailsForBox(widget.mailbox),
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
                  // Enhanced loading indicator with end-of-list detection
                  if (index == _dateKeys.length) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      child:
                          _allMessagesLoaded
                              ? Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      color: Theme.of(context).colorScheme.tertiary,
                                      size: 24,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'All emails loaded',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(context).colorScheme.tertiary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_processedUIDs.length} emails total',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                              : _isLoadingMore
                              ? Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 20,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      widget.isDarkMode
                                          ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
                                              alpha: 0.3,
                                            )
                                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: widget.isDarkMode
                                          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.16)
                                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Loading more emails...',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Theme.of(context).colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Fetching from server',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                        const SizedBox(height: 1),
                                        Text(
                                          '${_processedUIDs.length} emails loaded',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              )
                              : const SizedBox.shrink(),
                    );
                  }

                  final dateKey = _dateKeys[index];
                  final messagesForDate = _groupedMessages[dateKey] ?? [];

                  return OptimizedDateGroup(
                    date: dateKey,
                    messages: messagesForDate,
                    mailBox: widget.mailbox,
                    theme: widget.theme,
                    isDarkMode: widget.isDarkMode,
                  );
                },
                childCount:
                    _dateKeys.length +
                    (_isLoadingMore || _allMessagesLoaded ? 1 : 0),
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
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _formatDate(date),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary,
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
                // P12.2: Delegate open orchestration to MailboxViewModel (central gating, no UI change)
                MailboxViewModel vm;
                try {
                  vm = Get.find<MailboxViewModel>();
                } catch (_) {
                  vm = Get.put<MailboxViewModel>(getIt<MailboxViewModel>());
                }
                final mailboxController = Get.find<MailBoxController>();
                vm.openMessage(
                  controller: mailboxController,
                  mailbox: mailBox,
                  message: message,
                );
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
    final monthAgo = today.subtract(const Duration(days: 30));

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else if (dateOnly.isAfter(weekAgo)) {
      // This week - show day name
      const days = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return days[date.weekday - 1];
    } else if (dateOnly.isAfter(monthAgo) && date.year == now.year) {
      // This month - show "Week of" format for better organization
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}';
    } else if (date.year == now.year) {
      // This year - show month and day
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}';
    } else {
      // Different year - show full date
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
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
    return MailTile(message: message, mailBox: mailBox, onTap: onTap);
  }
}
