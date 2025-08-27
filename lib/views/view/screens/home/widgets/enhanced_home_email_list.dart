import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/app/controllers/selection_controller.dart';
import 'package:wahda_bank/widgets/mail_tile.dart';
import 'package:wahda_bank/views/view/showmessage/show_message.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

/// Enhanced Home Email List with proper first-time initialization
/// Best practices implementation for email loading and error handling
class EnhancedHomeEmailList extends StatefulWidget {
  const EnhancedHomeEmailList({super.key});

  @override
  State<EnhancedHomeEmailList> createState() => _EnhancedHomeEmailListState();
}

class _EnhancedHomeEmailListState extends State<EnhancedHomeEmailList>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  
  // Controllers
  late final MailBoxController controller;
  late final SelectionController selectionController;
  
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
    } catch (e) {
      debugPrint('❌ Error initializing controllers: $e');
      // Fallback: Put controllers if not found
      controller = Get.put(MailBoxController());
      selectionController = Get.put(SelectionController());
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
      debugPrint('🏠 Starting first-time home initialization...');
      
      // Step 1: Ensure inbox is initialized
      await _ensureInboxInitialized();
      
      // Step 2: Load initial emails with retry logic
      await _loadInitialEmailsWithRetry();
      
      // Step 3: Mark as successfully initialized
      _hasInitialized = true;
      _retryCount = 0;
      
      debugPrint('🏠 ✅ First-time initialization completed successfully');
      
    } catch (e) {
      debugPrint('🏠 ❌ First-time initialization failed: $e');
      _lastError = e.toString();
      
      // Schedule retry if not exceeded max attempts
      if (_retryCount < _maxRetries) {
        _retryCount++;
        debugPrint('🏠 ⏳ Scheduling retry $_retryCount/$_maxRetries in ${_retryDelay.inSeconds}s');
        
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

  /// Ensure inbox is properly initialized
  Future<void> _ensureInboxInitialized() async {
    try {
      // Initialize inbox if not already done
      if (controller.mailBoxInbox.path.isEmpty) {
        debugPrint('🏠 Initializing inbox...');
        await controller.initInbox();
        
        // Wait for inbox to be properly set up
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Verify inbox is ready
      if (controller.mailBoxInbox.path.isEmpty) {
        throw Exception('Inbox initialization failed - path is empty');
      }
      
      debugPrint('🏠 ✅ Inbox initialized: ${controller.mailBoxInbox.path}');
      
    } catch (e) {
      debugPrint('🏠 ❌ Inbox initialization error: $e');
      rethrow;
    }
  }

  /// Load initial emails with retry logic and timeout handling
  Future<void> _loadInitialEmailsWithRetry() async {
    const Duration timeout = Duration(seconds: 30);
    
    try {
      debugPrint('🏠 Loading initial emails...');
      
      // Load emails with timeout
      await controller.loadEmailsForBox(controller.mailBoxInbox)
          .timeout(timeout);
      
      // Verify emails were loaded
      final emailCount = controller.boxMails.length;
      debugPrint('🏠 ✅ Loaded $emailCount emails');
      
      if (emailCount == 0) {
        debugPrint('🏠 ⚠️ No emails found in inbox');
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
      await controller.loadMoreEmails(controller.mailBoxInbox, 50);
      debugPrint('🏠 ✅ Loaded more emails');
      
    } catch (e) {
      debugPrint('🏠 ❌ Error loading more emails: $e');
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
      await controller.refreshMailbox(controller.mailBoxInbox);
      debugPrint('🏠 ✅ Emails refreshed');
      
    } catch (e) {
      debugPrint('🏠 ❌ Error refreshing emails: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh emails: ${e.toString()}'),
            backgroundColor: Colors.red,
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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Obx(() {
      // Show initialization loading
      if (_isInitializing && !_hasInitialized) {
        return _buildInitializationLoading(isDarkMode);
      }

      // Show initialization error
      if (_lastError != null && !_hasInitialized) {
        return _buildInitializationError(isDarkMode);
      }

      // Show main email list
      return _buildEmailList(isDarkMode);
    });
  }

  /// Build initialization loading screen
  Widget _buildInitializationLoading(bool isDarkMode) {
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
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Setting up your inbox...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _retryCount > 0 
                    ? 'Retry attempt $_retryCount/$_maxRetries'
                    : 'This may take a few moments',
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode 
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
  Widget _buildInitializationError(bool isDarkMode) {
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
              Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 24),
              Text(
                'Setup Failed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _lastError ?? 'Unknown error occurred',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDarkMode 
                      ? Colors.white.withValues(alpha: 0.7) 
                      : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _retryInitialization,
                icon: const Icon(Icons.refresh),
                label: Text(_retryCount >= _maxRetries ? 'Try Again' : 'Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build main email list
  Widget _buildEmailList(bool isDarkMode) {
    // Gate by readiness: only show messages that have full details prepared
    final readyEmails = controller.boxMails
        .where((m) => m.getHeaderValue('x-ready') == '1')
        .toList(growable: false)
      ..sort((a, b) {
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
      return _buildEmptyState(isDarkMode);
    }

    return RefreshIndicator(
      onRefresh: _refreshEmails,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: readyEmails.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= readyEmails.length) {
            return _buildLoadingMoreIndicator(isDarkMode);
          }

          final message = readyEmails[index];
          return _buildMessageTile(message);
        },
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState(bool isDarkMode) {
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
                Icon(
                  Icons.inbox_outlined,
                  size: 80,
                  color: isDarkMode 
                      ? Colors.white.withValues(alpha: 0.3) 
                      : Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No emails yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode 
                        ? Colors.white.withValues(alpha: 0.7) 
                        : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pull down to refresh',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode 
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

  /// Build loading more indicator
  Widget _buildLoadingMoreIndicator(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Loading more emails...',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode 
                  ? Colors.white.withValues(alpha: 0.7) 
                  : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build message tile
  Widget _buildMessageTile(MimeMessage message) {
    return MailTile(
      message: message,
      mailBox: controller.mailBoxInbox,
      onTap: () {
        if (selectionController.isSelecting) {
          selectionController.toggle(message);
        } else {
          Get.to(() => ShowMessage(
            message: message, 
            mailbox: controller.mailBoxInbox,
          ));
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

