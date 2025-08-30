import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/app/controllers/selection_controller.dart';
import 'package:wahda_bank/widgets/mail_tile.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/views/view/showmessage/show_message.dart';
import 'package:wahda_bank/views/view/showmessage/show_message_pager.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wahda_bank/services/ui_context_service.dart';

class HomeEmailList extends StatefulWidget {
  const HomeEmailList({super.key});

  @override
  State<HomeEmailList> createState() => _HomeEmailListState();
}

class _HomeEmailListState extends State<HomeEmailList> with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final MailBoxController controller = Get.find<MailBoxController>();
  final SelectionController selectionController = Get.find<SelectionController>();
  
  bool _isLoadingMore = false;
  bool _allMessagesLoaded = false;
  int _currentPage = 1;
  
  // Track processed messages to avoid duplicates
  final Set<int> _processedUIDs = <int>{};
  final Map<DateTime, List<MimeMessage>> _groupedMessages = {};
  final List<DateTime> _dateKeys = [];
  int _lastProcessedCount = 0;
  String _lastSignature = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);

    // Mark inbox visible
    try { UiContextService.instance.inboxVisible = true; } catch (_) {}
    try { UiContextService.instance.isAppForeground = true; } catch (_) {}
    
    // Initialize email loading for home screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeHomeEmails();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    try { UiContextService.instance.inboxVisible = false; } catch (_) {}
    super.dispose();
  }

  void _initializeHomeEmails() async {
    // Ensure inbox is initialized and emails are loaded
    if (controller.mailBoxInbox.messagesExists == 0) {
      await controller.initInbox();
    }
    
    // Load initial emails if not already loaded
    if (controller.boxMails.isEmpty) {
      await controller.loadEmailsForBox(controller.mailBoxInbox);
    }
    
    // Process the loaded messages
    _processMessages(controller.boxMails);
  }

  void _onScroll() {
    // Enhanced scroll detection for home screen
    if (!_scrollController.hasClients || _isLoadingMore || _allMessagesLoaded) return;
    
    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;
    
    // Trigger loading when user is within 500px of bottom for home screen
    if (currentScroll >= maxScroll - 500 && 
        currentScroll < maxScroll - 50 && 
        maxScroll > 0) {
      
      // Add haptic feedback
      try {
        HapticFeedback.selectionClick();
      } catch (e) {
        // Ignore haptic feedback errors
      }
      
      _loadMoreMessages();
    }
  }

  String _computeSignature(List<MimeMessage> messages) {
    final buf = StringBuffer();
    final take = messages.length > 200 ? 200 : messages.length;
    for (var i = 0; i < take; i++) {
      final m = messages[i];
      final id = m.uid ?? m.sequenceId ?? 0;
      final ready = m.getHeaderValue('x-ready') ?? '';
      buf.write('$id:$ready|');
    }
    return buf.toString();
  }

  void _processMessages(List<MimeMessage> messages) {
    // Skip only if signature matches (covers content changes when count stays same)
    final sig = _computeSignature(messages);
    if (_groupedMessages.isNotEmpty && sig == _lastSignature) {
      _lastProcessedCount = messages.length; // keep in sync
      return;
    }
    _lastSignature = sig;
    
    // Process ALL messages; unready ones will render with shimmer until ready
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

    // Sort ALL unique messages
    allUniqueMessages.sort((a, b) {
      final dateA = _getMessageDate(a);
      final dateB = _getMessageDate(b);
      return dateB.compareTo(dateA); // Newest first
    });

    // Group ALL messages by date
    for (final message in allUniqueMessages) {
      final date = _getMessageDate(message);
      final dateKey = DateTime(date.year, date.month, date.day);
      
      if (!_groupedMessages.containsKey(dateKey)) {
        _groupedMessages[dateKey] = [];
        _dateKeys.add(dateKey);
      }
      _groupedMessages[dateKey]!.add(message);
    }

    // Sort date keys
    _dateKeys.sort((a, b) => b.compareTo(a)); // Newest dates first
    
    if (mounted) {
      setState(() {});
    }
  }

  DateTime _getMessageDate(MimeMessage message) {
    try {
      return message.decodeDate() ?? 
             message.envelope?.date ?? 
             DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  void _loadMoreMessages() async {
    if (_isLoadingMore || !mounted || _allMessagesLoaded) return;
    
    final totalMessages = controller.boxMails.length;
    final currentlyDisplayed = _processedUIDs.length;
    
    // Check if we've reached the end
    final mailboxMessageCount = controller.mailBoxInbox.messagesExists;
    if (currentlyDisplayed >= mailboxMessageCount && mailboxMessageCount > 0) {
      _allMessagesLoaded = true;
      return;
    }
    
    setState(() {
      _isLoadingMore = true;
    });
    
    try {
      if (currentlyDisplayed >= totalMessages) {
        // Load more from server
        final previousCount = totalMessages;
        await controller.loadMoreEmails(controller.mailBoxInbox, _currentPage + 1);
        
        final newTotalMessages = controller.boxMails.length;
        if (newTotalMessages > previousCount) {
          _currentPage++;
          _processMessages(controller.boxMails);
        } else {
          _allMessagesLoaded = true;
        }
      } else {
        // Display more local messages
        await Future.delayed(const Duration(milliseconds: 50));
        _processMessages(controller.boxMails);
      }
    } catch (e) {
      debugPrint('Error loading more messages: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Obx(() {
      // Listen to controller changes
      final messages = controller.boxMails;
      
      // Update messages when controller changes (signature-based)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processMessages(messages);
      });
      
      if (_groupedMessages.isEmpty && !_isLoadingMore) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inbox_outlined,
                size: 64,
                color: isDarkMode ? Colors.white38 : Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No emails found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                  'Pull to refresh or check your connection',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white.withValues(alpha: 0.5) : Colors.grey.shade500,
                  ),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          _processedUIDs.clear();
          _lastSignature = '';
          await controller.refreshMailbox(controller.mailBoxInbox);
          await controller.refreshTopNow();
          _processMessages(controller.boxMails);
        },
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _dateKeys.length + 1, // +1 for loading indicator
          itemBuilder: (context, index) {
            // Loading indicator at the bottom
            if (index == _dateKeys.length) {
              return Container(
                padding: const EdgeInsets.all(16),
                child: _allMessagesLoaded
                  ? Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            color: isDarkMode 
                                  ? Colors.green.shade300 
                                  : Colors.green.shade600,
                            size: 24,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'All emails loaded',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode 
                                    ? Colors.green.shade300 
                                    : Colors.green.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_processedUIDs.length} emails total',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDarkMode 
                                    ? Colors.green.shade400 
                                    : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _isLoadingMore
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        decoration: BoxDecoration(
                          color: isDarkMode 
                                ? Colors.grey.shade800.withValues(alpha: 0.3)
                                : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: isDarkMode 
                                    ? Colors.black26 
                                    : Colors.grey.shade300,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                  Text(
                                    'Loading more emails...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDarkMode 
                                            ? Colors.white.withValues(alpha: 0.87) 
                                            : Colors.grey.shade700,
                                    ),
                                  ),
                                const SizedBox(height: 2),
                                Text(
                                  'Fetching from server',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode 
                                          ? Colors.white60 
                                          : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '${_processedUIDs.length} emails loaded',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDarkMode 
                                          ? Colors.white.withValues(alpha: 0.5) 
                                          : Colors.grey.shade500,
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

            return _buildDateGroup(dateKey, messagesForDate, isDarkMode);
          },
        ),
      );
    });
  }

  Widget _buildDateGroup(DateTime date, List<MimeMessage> messages, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            _formatDate(date),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
            ),
          ),
        ),
        // Messages for this date
        ...messages.map((message) => _buildMessageTile(message)),
      ],
    );
  }

  Widget _buildMessageTile(MimeMessage message) {
    final meta = controller.getMessageMetaNotifier(controller.mailBoxInbox, message);
    bool isReady() => message.getHeaderValue('x-ready') == '1';

    Widget openHandler(Widget child) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (selectionController.isSelecting) {
              selectionController.toggle(message);
            } else {
              try {
                final listRef = controller.emails[controller.mailBoxInbox] ?? const <MimeMessage>[];
                int index = 0;
                if (listRef.isNotEmpty) {
                  index = listRef.indexWhere((m) =>
                      (message.uid != null && m.uid == message.uid) ||
                      (message.sequenceId != null && m.sequenceId == message.sequenceId));
                  if (index < 0) index = 0;
                }
                Get.to(() => ShowMessagePager(mailbox: controller.mailBoxInbox, initialMessage: message));
              } catch (_) {
                Get.to(() => ShowMessage(message: message, mailbox: controller.mailBoxInbox));
              }
            }
          },
          child: child,
        );

    Widget shimmerRow() => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade200,
            highlightColor: Colors.grey.shade100,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 12, width: 160, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(6))),
                        const SizedBox(height: 8),
                        Container(height: 10, width: double.infinity, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(6))),
                        const SizedBox(height: 6),
                        Container(height: 10, width: MediaQuery.of(context).size.width * 0.5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(6))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(height: 10, width: 40, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(6))),
                ],
              ),
            ),
          ),
        );

    return ValueListenableBuilder<int>(
      valueListenable: meta,
      builder: (_, __, ___) {
        if (!isReady()) {
          return openHandler(shimmerRow());
        }
        return MailTile(
          message: message,
          mailBox: controller.mailBoxInbox,
          onTap: () {
            if (selectionController.isSelecting) {
              // Use the correct method to toggle selection
              selectionController.toggle(message);
            } else {
              try {
                final listRef = controller.emails[controller.mailBoxInbox] ?? const <MimeMessage>[];
                int index = 0;
                if (listRef.isNotEmpty) {
                  index = listRef.indexWhere((m) =>
                      (message.uid != null && m.uid == message.uid) ||
                      (message.sequenceId != null && m.sequenceId == message.sequenceId));
                  if (index < 0) index = 0;
                }
                Get.to(() => ShowMessagePager(mailbox: controller.mailBoxInbox, initialMessage: message));
              } catch (_) {
                Get.to(() => ShowMessage(message: message, mailbox: controller.mailBoxInbox));
              }
            }
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(messageDate).inDays < 7) {
      const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return weekdays[date.weekday - 1];
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      try { UiContextService.instance.isAppForeground = true; } catch (_) {}
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      try { UiContextService.instance.isAppForeground = false; } catch (_) {}
    }
  }
}

