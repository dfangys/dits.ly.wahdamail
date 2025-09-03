import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/app/controllers/selection_controller.dart';
import 'package:wahda_bank/widgets/mail_tile.dart';
import 'package:wahda_bank/views/view/showmessage/show_message.dart';
import 'package:wahda_bank/views/view/showmessage/show_message_pager.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/services/feature_flags.dart';
import 'package:wahda_bank/widgets/progress_indicator_widget.dart';
import 'package:wahda_bank/shared/di/injection.dart';
import 'package:wahda_bank/features/messaging/presentation/mailbox_view_model.dart';
import 'package:wahda_bank/design_system/components/empty_state.dart';
import 'package:wahda_bank/design_system/components/error_state.dart';

/// Enhanced Mailbox View with proper first-time initialization
/// Best practices implementation for mailbox email loading and error handling
class EnhancedMailboxView extends StatefulWidget {
  final Mailbox mailbox;
  final ThemeData theme;
  final bool isDarkMode;

  const EnhancedMailboxView({
    super.key,
    required this.mailbox,
    required this.theme,
    required this.isDarkMode,
  });

  @override
  State<EnhancedMailboxView> createState() => _EnhancedMailboxViewState();
}

class _EnhancedMailboxViewState extends State<EnhancedMailboxView>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  // Controllers
  late final MailBoxController controller;
  late final SelectionController selectionController;
  late final MailboxViewModel mailboxVm;

  // Scroll and loading management
  final ScrollController _scrollController = ScrollController();
  final Set<String> _processedUIDs = <String>{};

  // State management
  bool _isInitializing = false;
  bool _isLoadingMore = false;
  bool _hasInitialized = false;
  String? _lastError;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // Performance optimization
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeControllers();
    _setupScrollListener();

    // Delayed initialization to ensure proper widget tree setup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performFirstTimeInitialization();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  /// Initialize controllers with proper error handling
  void _initializeControllers() {
    try {
      controller = Get.find<MailBoxController>();
      selectionController = Get.find<SelectionController>();
      mailboxVm = Get.find<MailboxViewModel>();
    } catch (e) {
      debugPrint('❌ Error initializing controllers: $e');
      // Fallback: Put controllers if not found
      controller = Get.put(MailBoxController());
      selectionController = Get.put(SelectionController());
      mailboxVm = Get.put<MailboxViewModel>(getIt<MailboxViewModel>());
    }
  }

  /// Setup scroll listener for pagination
  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 500) {
        _loadMoreEmails();
      }
    });
  }

  /// First-time initialization with comprehensive error handling
  Future<void> _performFirstTimeInitialization() async {
    if (_isInitializing || _hasInitialized) return;

    setState(() {
      _isInitializing = true;
      _lastError = null;
    });

    try {
      debugPrint(
        '📫 Starting first-time mailbox initialization for: ${widget.mailbox.path}',
      );

      // Step 1: Ensure mailbox is properly selected
      await _ensureMailboxSelected();

      // Step 2: Load initial emails with retry logic
      await _loadInitialEmailsWithRetry();

      // Step 3: Mark as successfully initialized
      _hasInitialized = true;
      _retryCount = 0;

      debugPrint(
        '📫 ✅ First-time mailbox initialization completed successfully',
      );
    } catch (e) {
      debugPrint('📫 ❌ First-time mailbox initialization failed: $e');
      _lastError = e.toString();

      // Schedule retry if not exceeded max attempts
      if (_retryCount < _maxRetries) {
        _retryCount++;
        debugPrint(
          '📫 ⏳ Scheduling retry $_retryCount/$_maxRetries in ${_retryDelay.inSeconds}s',
        );

        Future.delayed(_retryDelay, () {
          if (mounted && !_hasInitialized) {
            _performFirstTimeInitialization();
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  /// Ensure mailbox is properly selected
  Future<void> _ensureMailboxSelected() async {
    try {
      // Check if mailbox is already selected
      if (controller.currentMailbox?.path == widget.mailbox.path) {
        debugPrint('📫 ✅ Mailbox already selected: ${widget.mailbox.path}');
        return;
      }

      debugPrint('📫 Selecting mailbox: ${widget.mailbox.path}');

      // If another load is in-flight, wait briefly for it to complete to avoid racing
      final stopwatch = Stopwatch()..start();
      while (controller.isLoadingEmails.value &&
          stopwatch.elapsed < const Duration(seconds: 10)) {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Select the mailbox with timeout
      await controller
          .loadEmailsForBox(widget.mailbox)
          .timeout(const Duration(seconds: 20));

      // Verify mailbox was selected, wait a tiny grace period for state to settle
      if (controller.currentMailbox?.path != widget.mailbox.path) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
      if (controller.currentMailbox?.path != widget.mailbox.path) {
        throw Exception(
          'Mailbox selection failed - current: ${controller.currentMailbox?.path}',
        );
      }

      debugPrint('📫 ✅ Mailbox selected: ${widget.mailbox.path}');
    } catch (e) {
      debugPrint('📫 ❌ Mailbox selection error: $e');
      rethrow;
    }
  }

  /// Load initial emails with retry logic and timeout handling
  Future<void> _loadInitialEmailsWithRetry() async {
    const Duration timeout = Duration(seconds: 30);

    try {
      debugPrint('📫 Loading initial emails for: ${widget.mailbox.path}');

      // Load emails with timeout
      await controller.loadEmailsForBox(widget.mailbox).timeout(timeout);

      // Verify emails were loaded
      final emailCount = controller.emails[widget.mailbox]?.length ?? 0;
      debugPrint('📫 ✅ Loaded $emailCount emails for ${widget.mailbox.path}');

      if (emailCount == 0) {
        debugPrint('📫 ⚠️ No emails found in ${widget.mailbox.path}');
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Email loading timeout - server may be slow');
      } else if (e.toString().contains('Connection timeout')) {
        throw Exception('Connection timeout - check network connectivity');
      } else {
        throw Exception('Email loading failed: ${e.toString()}');
      }
    }
  }

  /// Load more emails for pagination
  Future<void> _loadMoreEmails() async {
    if (_isLoadingMore || !_hasInitialized) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      HapticFeedback.lightImpact();
      await controller.loadMoreEmails(widget.mailbox, 50);
      debugPrint('📫 ✅ Loaded more emails for ${widget.mailbox.path}');
    } catch (e) {
      debugPrint('📫 ❌ Error loading more emails: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  /// Refresh emails (pull-to-refresh)
  Future<void> _refreshEmails() async {
    try {
      HapticFeedback.mediumImpact();
      _processedUIDs.clear();
      await controller.refreshMailbox(widget.mailbox);
      debugPrint('📫 ✅ Emails refreshed for ${widget.mailbox.path}');
    } catch (e) {
      debugPrint('📫 ❌ Error refreshing emails: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh emails: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Retry initialization manually
  void _retryInitialization() {
    _retryCount = 0;
    _hasInitialized = false;
    _lastError = null;
    _performFirstTimeInitialization();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Prefer granular rebuilds driven by storage notifier when available
    final storage = controller.mailboxStorage[widget.mailbox];

    if (storage == null) {
      // Fallback to previous behavior if storage not ready
      return Obx(() {
        Widget base;
        if (_isInitializing && !_hasInitialized) {
          base = _buildInitializationLoading();
        } else if (_lastError != null && !_hasInitialized) {
          base = _buildInitializationError();
        } else {
          base = _buildEmailList(
            controller.emails[widget.mailbox] ?? const <MimeMessage>[],
          );
        }
        return Stack(children: [base, _buildProgressOverlay()]);
      });
    }

    return ValueListenableBuilder<List<MimeMessage>>(
      valueListenable: storage.dataNotifier,
      builder: (context, messages, _) {
        Widget base;
        if (_isInitializing && !_hasInitialized) {
          base = _buildInitializationLoading();
        } else if (_lastError != null && !_hasInitialized) {
          base = _buildInitializationError();
        } else {
          base = _buildEmailList(messages);
        }
        return Stack(children: [base, _buildProgressOverlay()]);
      },
    );
  }

  Widget _buildProgressOverlay() {
    final pc = Get.find<EmailDownloadProgressController>();
    return Obx(() {
      final shouldShow =
          pc.isVisible ||
          controller.isLoadingEmails.value ||
          controller.isPrefetching.value;
      if (!shouldShow) return const SizedBox.shrink();
      return Align(
        alignment: Alignment.bottomCenter,
        child: SafeArea(
          minimum: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            child: EmailDownloadProgressWidget(
              title: pc.title,
              subtitle: pc.subtitle,
              progress: pc.isIndeterminate ? null : pc.progress,
              currentCount: pc.currentCount,
              totalCount: pc.totalCount,
              isIndeterminate: pc.isIndeterminate,
              compact: true,
              actionLabel: _downloadAllActionLabel(),
              onAction: _onDownloadAllPressed,
            ),
          ),
        ),
      );
    });
  }

  String? _downloadAllActionLabel() {
    final mb = controller.currentMailbox;
    if (mb == null) return null;
    const initialWindow = 200;
    if (mb.messagesExists > initialWindow) {
      return 'Download all';
    }
    return null;
  }

  void _onDownloadAllPressed() {
    final mb = controller.currentMailbox;
    if (mb != null) {
      controller.downloadAllEmails(mb);
    }
  }

  /// Build initialization loading screen
  Widget _buildInitializationLoading() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        elevation: 8,
        shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                height: 60,
                width: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Loading ${widget.mailbox.name}...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color:
                      widget.isDarkMode ? Colors.white : Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _retryCount > 0
                    ? 'Retry attempt $_retryCount/$_maxRetries'
                    : 'This may take a few moments',
                style: TextStyle(
                  fontSize: 14,
                  color:
                      widget.isDarkMode
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build initialization error screen
  Widget _buildInitializationError() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        elevation: 8,
        shadowColor: Colors.red.withValues(alpha: 0.3),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ErrorState(title: 'Loading Failed', message: _lastError),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _retryInitialization,
                icon: const Icon(Icons.refresh),
                label: Text(_retryCount >= _maxRetries ? 'Try Again' : 'Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build main email list
  bool _isMessageReady(MimeMessage m) {
    // Strict gating: only show when full-content prefetch (or DB-derived) marked message as ready
    return m.getHeaderValue('x-ready') == '1';
  }

  Widget _buildEmailList(List<MimeMessage> emails) {
    // Filter only ready messages for display
    final readyEmails = emails
      .where(_isMessageReady)
      .toList(growable: false)..sort((a, b) {
      // Enterprise-grade stable ordering: UID desc > sequenceId desc > date desc
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
    if (readyEmails.isEmpty) {
      return _buildEmptyState();
    }

    // Disable fixed extent for very large text scales to avoid overflow.
    final textScale = MediaQuery.of(context).textScaler.scale(14.0) / 14.0;
    bool useFixedExtent =
        FeatureFlags.instance.virtualizationTuningEnabled &&
        FeatureFlags.instance.fixedExtentListEnabled &&
        textScale <= 1.3;
    final double? extent = useFixedExtent ? _fixedTileExtent(context) : null;

    return RefreshIndicator(
      onRefresh: _refreshEmails,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        // Virtualization tuning
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        addSemanticIndexes: false,
        cacheExtent:
            FeatureFlags.instance.virtualizationTuningEnabled
                ? 6 * 120.0
                : null,
        prototypeItem:
            (FeatureFlags.instance.virtualizationTuningEnabled &&
                    !useFixedExtent)
                ? const SizedBox(height: 112)
                : null,
        itemExtent: extent,
        itemCount: readyEmails.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= readyEmails.length) {
            return _buildLoadingMoreIndicator();
          }

          final message = readyEmails[index];
          // Animated entry for newly ready messages
          return RepaintBoundary(child: _animatedTile(message));
        },
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
    final pc = Get.find<EmailDownloadProgressController>();
    return RefreshIndicator(
      onRefresh: _refreshEmails,
      color: AppTheme.primaryColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          Center(
            child: Column(
              children: [
                Obx(() {
                  final preparing =
                      pc.isVisible ||
                      controller.isLoadingEmails.value ||
                      controller.isPrefetching.value;
                  return preparing
                      ? const EmptyState(title: 'Preparing messages…')
                      : EmptyState(title: 'No emails in ${widget.mailbox.name}');
                }),
                const SizedBox(height: 8),
                Text(
                  'Pull down to refresh',
                  style: TextStyle(
                    fontSize: 14,
                    color:
                        widget.isDarkMode
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _fixedTileExtent(BuildContext context) {
    // Base tile height tuned for 2-line preview and current paddings; add buffer for text scale.
    final textScaler = MediaQuery.of(context).textScaler;
    // Derive a scale factor relative to a nominal 14px font.
    final scale = (textScaler.scale(14.0) / 14.0).clamp(0.9, 1.5);
    const base = 116.0; // Slightly higher base to avoid edge overflows
    final extra = (scale - 1.0) * 28.0; // Add vertical buffer as text grows
    return base + extra;
  }

  /// Build loading more indicator
  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                height: 20,
                width: 20,
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
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color:
                          widget.isDarkMode
                              ? Colors.white.withValues(alpha: 0.87)
                              : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Fetching from server',
                    style: TextStyle(
                      fontSize: 8,
                      color:
                          widget.isDarkMode
                              ? Colors.white60
                              : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${_processedUIDs.length} emails loaded',
                    style: TextStyle(
                      fontSize: 8,
                      color:
                          widget.isDarkMode
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _msgKey(MimeMessage m) {
    final id = m.uid ?? m.sequenceId;
    return '${widget.mailbox.encodedPath}:${id ?? m.hashCode}';
  }

  Widget _animatedTile(MimeMessage message) {
    final key = _msgKey(message);
    final firstTime = !_processedUIDs.contains(key);
    if (firstTime) _processedUIDs.add(key);

    final tile = _buildMessageTile(message);
    if (!firstTime) return tile;

    // Fade + slide-in animation for first appearance
    return TweenAnimationBuilder<double>(
      key: ValueKey(key),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      builder: (context, t, child) {
        final dy = (1.0 - t) * 12.0; // small upward slide
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
      child: tile,
    );
  }

  /// Build message tile
  Widget _buildMessageTile(MimeMessage message) {
    return MailTile(
      message: message,
      mailBox: widget.mailbox,
      onTap: () {
        if (selectionController.isSelecting) {
          selectionController.toggle(message);
        } else {
          try {
            // Use safe navigation that routes drafts to Compose and others to ShowMessage
            final mbc = Get.find<MailBoxController>();
            mailboxVm.openMessage(
              controller: mbc,
              mailbox: widget.mailbox,
              message: message,
            );
          } catch (_) {
            // Fallbacks in case controller lookup or navigation fails
            try {
              Get.to(
                () => ShowMessagePager(
                  mailbox: widget.mailbox,
                  initialMessage: message,
                ),
              );
            } catch (_) {
              Get.to(
                () => ShowMessage(message: message, mailbox: widget.mailbox),
              );
            }
          }
        }
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Refresh when app comes to foreground
    if (state == AppLifecycleState.resumed && _hasInitialized) {
      _refreshEmails();
    }
  }
}
