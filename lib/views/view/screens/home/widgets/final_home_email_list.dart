import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/app/controllers/selection_controller.dart';
import 'package:wahda_bank/widgets/mail_tile.dart';
import 'package:wahda_bank/views/view/showmessage/show_message.dart';
import 'package:wahda_bank/utills/constants/colors.dart';

class FinalHomeEmailList extends StatefulWidget {
  const FinalHomeEmailList({Key? key}) : super(key: key);

  @override
  State<FinalHomeEmailList> createState() => _FinalHomeEmailListState();
}

class _FinalHomeEmailListState extends State<FinalHomeEmailList> 
    with AutomaticKeepAliveClientMixin {
  
  // CRITICAL: Keep state alive during navigation
  @override
  bool get wantKeepAlive => true;
  
  final MailBoxController _controller = Get.find<MailBoxController>();
  final SelectionController _selectionController = Get.find<SelectionController>();
  final ScrollController _scrollController = ScrollController();
  
  bool _isLoadingMore = false;
  bool _hasInitialized = false;
  
  @override
  void initState() {
    super.initState();
    _initializeEmailLoading();
    _setupScrollListener();
  }
  
  void _initializeEmailLoading() async {
    if (_hasInitialized) return;
    
    try {
      // Ensure inbox is initialized
      if (!_controller.isInboxInitialized) {
        await _controller.initInbox();
      }
      
      // Load emails if inbox is empty
      final inbox = _controller.mailboxes.firstWhereOrNull(
        (box) => box.name.toLowerCase() == 'inbox'
      );
      
      if (inbox != null) {
        final currentEmails = _controller.emails[inbox] ?? [];
        if (currentEmails.isEmpty) {
          await _controller.loadEmailsForBox(inbox);
        }
      }
      
      _hasInitialized = true;
    } catch (e) {
      debugPrint('🏠 ❌ Error initializing emails: $e');
    }
  }
  
  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 600) {
        _loadMoreEmails();
      }
    });
  }
  
  void _loadMoreEmails() async {
    if (_isLoadingMore) return;
    
    final inbox = _controller.mailboxes.firstWhereOrNull(
      (box) => box.name.toLowerCase() == 'inbox'
    );
    
    if (inbox == null) return;
    
    final currentEmails = _controller.emails[inbox] ?? [];
    final totalEmails = _controller.mailboxes
        .firstWhereOrNull((box) => box.name.toLowerCase() == 'inbox')
        ?.messagesExists ?? 0;
    
    // CRITICAL FIX: Prevent infinite loading
    if (currentEmails.length >= totalEmails) {
      debugPrint('🏠 ✅ All emails loaded (${currentEmails.length}/$totalEmails)');
      return;
    }
    
    setState(() => _isLoadingMore = true);
    
    try {
      await _controller.loadMoreEmails(inbox);
      HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('🏠 ❌ Error loading more emails: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    return Obx(() {
      final inbox = _controller.mailboxes.firstWhereOrNull(
        (box) => box.name.toLowerCase() == 'inbox'
      );
      
      if (inbox == null) {
        return _buildEmptyState('No inbox found');
      }
      
      final emails = _controller.emails[inbox] ?? [];
      
      if (_controller.isBusy.value && emails.isEmpty) {
        return _buildLoadingState();
      }
      
      if (emails.isEmpty) {
        return _buildEmptyState('No emails found');
      }
      
      return RefreshIndicator(
        onRefresh: () => _refreshEmails(inbox),
        color: Theme.of(context).primaryColor,
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: emails.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= emails.length) {
              return _buildLoadingIndicator(emails.length, inbox);
            }
            
            final message = emails[index];
            return _buildEmailTile(message, inbox);
          },
        ),
      );
    });
  }
  
  Widget _buildEmailTile(MimeMessage message, Mailbox inbox) {
    return MailTile(
      message: message,
      mailBox: inbox,
      onTap: () => _navigateToMessage(message, inbox),
    );
  }
  
  void _navigateToMessage(MimeMessage message, Mailbox inbox) {
    Get.to(() => ShowMessage(
      message: message,
      mailbox: inbox,
    ));
  }
  
  Future<void> _refreshEmails(Mailbox inbox) async {
    try {
      await _controller.refreshMailbox(inbox);
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('🏠 ❌ Error refreshing emails: $e');
    }
  }
  
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading emails...'),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _initializeEmailLoading,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLoadingIndicator(int currentCount, Mailbox inbox) {
    final totalEmails = inbox.messagesExists ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 8),
          Text(
            'Loading more emails... ($currentCount/$totalEmails)',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}

