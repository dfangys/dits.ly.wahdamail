import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/app/controllers/selection_controller.dart';
import 'package:wahda_bank/widgets/mail_tile.dart';
import 'package:wahda_bank/views/view/showmessage/show_message.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

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
      debugPrint('📫 Starting first-time mailbox initialization for: ${widget.mailbox.path}');
      
      // Step 1: Ensure mailbox is properly selected
      await _ensureMailboxSelected();
      
      // Step 2: Load initial emails with retry logic
      await _loadInitialEmailsWithRetry();
      
      // Step 3: Mark as successfully initialized
      _hasInitialized = true;
      _retryCount = 0;
      
      debugPrint('📫 ✅ First-time mailbox initialization completed successfully');
      
    } catch (e) {
      debugPrint('📫 ❌ First-time mailbox initialization failed: $e');
      _lastError = e.toString();
      
      // Schedule retry if not exceeded max attempts
      if (_retryCount < _maxRetries) {
        _retryCount++;
        debugPrint('📫 ⏳ Scheduling retry $_retryCount/$_maxRetries in ${_retryDelay.inSeconds}s');
        
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
      
      // Select the mailbox with timeout
      await controller.loadEmailsForBox(widget.mailbox)
          .timeout(const Duration(seconds: 15));
      
      // Verify mailbox was selected
      if (controller.currentMailbox?.path != widget.mailbox.path) {
        throw Exception('Mailbox selection failed - current: ${controller.currentMailbox?.path}');
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
      await controller.loadEmailsForBox(widget.mailbox)
          .timeout(timeout);
      
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

    return Obx(() {
      // Show initialization loading
      if (_isInitializing && !_hasInitialized) {
        return _buildInitializationLoading();
      }

      // Show initialization error
      if (_lastError != null && !_hasInitialized) {
        return _buildInitializationError();
      }

      // Show main email list
      return _buildEmailList();
    });
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
              SizedBox(
                height: 60,
                width: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Loading ${widget.mailbox.name}...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: widget.isDarkMode ? Colors.white : Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _retryCount > 0 
                    ? 'Retry attempt $_retryCount/$_maxRetries'
                    : 'This may take a few moments',
                style: TextStyle(
                  fontSize: 14,
                  color: widget.isDarkMode 
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
              Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 24),
              Text(
                'Loading Failed',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: widget.isDarkMode ? Colors.white : Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _lastError ?? 'Unknown error occurred',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.isDarkMode 
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
  Widget _buildEmailList() {
    final emails = controller.emails[widget.mailbox] ?? [];
    
    if (emails.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshEmails,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: emails.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= emails.length) {
            return _buildLoadingMoreIndicator();
          }

          final message = emails[index];
          return _buildMessageTile(message);
        },
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState() {
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
                  Icons.folder_outlined,
                  size: 80,
                  color: widget.isDarkMode 
                      ? Colors.white.withValues(alpha: 0.3) 
                      : Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No emails in ${widget.mailbox.name}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: widget.isDarkMode 
                        ? Colors.white.withValues(alpha: 0.7) 
                        : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pull down to refresh',
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.isDarkMode 
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
              SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
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
                      color: widget.isDarkMode 
                          ? Colors.white.withValues(alpha: 0.87) 
                          : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Fetching from server',
                    style: TextStyle(
                      fontSize: 12,
                      color: widget.isDarkMode 
                            ? Colors.white60 
                            : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${_processedUIDs.length} emails loaded',
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isDarkMode 
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

  /// Build message tile
  Widget _buildMessageTile(MimeMessage message) {
    return MailTile(
      message: message,
      mailBox: widget.mailbox,
      onTap: () {
        if (selectionController.isSelecting) {
          selectionController.toggle(message);
        } else {
          Get.to(() => ShowMessage(
            message: message, 
            mailbox: widget.mailbox,
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

