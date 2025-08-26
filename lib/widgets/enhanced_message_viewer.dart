import 'package:flutter/material.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail_flutter/enough_mail_flutter.dart';
import 'package:flutter/foundation.dart';
import '../utills/theme/app_theme.dart';

/// Enhanced message viewer implementing enough_mail best practices
class EnhancedMessageViewer extends StatefulWidget {
  const EnhancedMessageViewer({
    super.key,
    required this.mimeMessage,
    this.maxImageWidth,
    this.enableDarkMode = false,
    this.emptyMessageText = 'No message content available',
    this.onZoomed,
    this.blockExternalImages = true,
    this.preferPlainText = false,
  });

  final MimeMessage mimeMessage;
  final int? maxImageWidth;
  final bool enableDarkMode;
  final String emptyMessageText;
  final void Function()? onZoomed;
  final bool blockExternalImages;
  final bool preferPlainText;

  @override
  State<EnhancedMessageViewer> createState() => _EnhancedMessageViewerState();
}

class _EnhancedMessageViewerState extends State<EnhancedMessageViewer> {
  bool _showImages = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return _buildMessageContent();
  }

  Widget _buildMessageContent() {
    try {
      // Check if message has content
      if (!_hasMessageContent()) {
        return _buildEmptyMessage();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // External images warning
          if (widget.blockExternalImages && _hasExternalImages() && !_showImages)
            _buildExternalImagesWarning(),

          // Message content
          _buildContent(),

          // Loading indicator
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),

          // Error message
          if (_errorMessage != null)
            _buildErrorMessage(),
        ],
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error building message content: $e');
      }
      return _buildErrorMessage(error: e.toString());
    }
  }

  Widget _buildContent() {
    try {
      if (kDebugMode) {
        print('DEBUG: Building message content');
        print('DEBUG: Message parts count: ${widget.mimeMessage.parts?.length ?? 0}');
        print('DEBUG: Message content type: ${widget.mimeMessage.mediaType}');
      }
      
      // Enhanced MimeMessageViewer with proper configuration
      return MimeMessageViewer(
        mimeMessage: widget.mimeMessage,
        maxImageWidth: widget.maxImageWidth,
        enableDarkMode: widget.enableDarkMode,
        emptyMessageText: widget.emptyMessageText,
        blockExternalImages: widget.blockExternalImages && !_showImages,
        preferPlainText: widget.preferPlainText,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error creating MimeMessageViewer: $e');
      }
      return _buildErrorMessage(error: 'Failed to display message content');
    }
  }

  Widget _buildEmptyMessage() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mail_outline,
            size: 64,
            color: AppTheme.textSecondaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            widget.emptyMessageText,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildExternalImagesWarning() {
    return Container(
      margin: const EdgeInsets.all(8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          Icon(
            Icons.image_not_supported,
            color: Colors.orange.shade700,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'External images blocked',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This message contains external images that have been blocked for your privacy.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: () {
              setState(() {
                _showImages = true;
              });
            },
            child: const Text('Show Images'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage({String? error}) {
    final errorText = error ?? _errorMessage ?? 'Unknown error occurred';
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: AppTheme.errorColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading message content',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.errorColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            errorText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _errorMessage = null;
                _isLoading = true;
              });
              // Trigger rebuild
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                }
              });
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  bool _hasMessageContent() {
    try {
      // Check for text content
      final plainText = widget.mimeMessage.decodeTextPlainPart();
      if (plainText != null && plainText.trim().isNotEmpty) {
        return true;
      }

      // Check for HTML content
      final htmlText = widget.mimeMessage.decodeTextHtmlPart();
      if (htmlText != null && htmlText.trim().isNotEmpty) {
        return true;
      }

      // Check for attachments
      if (widget.mimeMessage.hasAttachments()) {
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking message content: $e');
      }
      return false;
    }
  }

  bool _hasExternalImages() {
    try {
      final htmlText = widget.mimeMessage.decodeTextHtmlPart();
      if (htmlText == null) return false;

      // Simple check for external images
      return htmlText.contains('<img') && 
             (htmlText.contains('http://') || htmlText.contains('https://'));
    } catch (e) {
      if (kDebugMode) {
        print('Error checking external images: $e');
      }
      return false;
    }
  }
}

