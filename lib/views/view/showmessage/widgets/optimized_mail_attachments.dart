import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail_flutter/enough_mail_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:open_app_file/open_app_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../services/mail_service.dart';
import '../../../../utills/theme/app_theme.dart';

class OptimizedMailAttachments extends StatefulWidget {
  const OptimizedMailAttachments({
    super.key, 
    required this.message, 
    this.mailbox,
  });
  
  final MimeMessage message;
  final Mailbox? mailbox;

  @override
  State<OptimizedMailAttachments> createState() => _OptimizedMailAttachmentsState();
}

class _OptimizedMailAttachmentsState extends State<OptimizedMailAttachments> {
  // Static caches for better performance
  static final Map<String, MimeMessage> _contentCache = {};
  static final Map<String, List<MimePart>> _attachmentCache = {};
  static final Map<String, Uint8List> _attachmentDataCache = {};
  
  MimeMessage? _cachedMessage;
  List<MimePart> _attachments = [];
  bool _isLoading = false;
  String? _error;
  
  String get _messageKey => '${widget.message.uid ?? widget.message.sequenceId}';

  @override
  void initState() {
    super.initState();
    _loadMessageContent();
  }

  Future<void> _loadMessageContent() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Check cache first
      if (_contentCache.containsKey(_messageKey)) {
        _cachedMessage = _contentCache[_messageKey];
        _attachments = _attachmentCache[_messageKey] ?? [];
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Fetch with optimized connection handling
      final messageContent = await _fetchMessageContentOptimized();
      
      // Cache the results
      _contentCache[_messageKey] = messageContent;
      _cachedMessage = messageContent;
      
      // Extract attachments
      _attachments = messageContent.findContentInfo(disposition: ContentDisposition.attachment);
      _attachmentCache[_messageKey] = _attachments;
      
      // Preload small attachments in background
      _preloadSmallAttachments();
      
    } catch (e) {
      setState(() {
        _error = 'Error loading message content: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<MimeMessage> _fetchMessageContentOptimized() async {
    final mailService = MailService.instance;
    
    // Connection with timeout
    if (!mailService.client.isConnected) {
      await mailService.connect().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException("Connection timeout", const Duration(seconds: 10)),
      );
    }
    
    // Mailbox selection with timeout
    if (widget.mailbox != null) {
      final currentMailbox = mailService.client.selectedMailbox;
      if (currentMailbox == null || currentMailbox.path != widget.mailbox!.path) {
        await mailService.client.selectMailbox(widget.mailbox!).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException("Mailbox selection timeout", const Duration(seconds: 10)),
        );
      }
    }
    
    // Fetch content with retry logic
    return await _fetchWithRetry();
  }

  Future<MimeMessage> _fetchWithRetry() async {
    int retryCount = 0;
    const maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        return await MailService.instance.client.fetchMessageContents(widget.message).timeout(
          const Duration(seconds: 30),
          onTimeout: () => throw TimeoutException("Content fetch timeout", const Duration(seconds: 30)),
        );
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) rethrow;
        
        // Exponential backoff
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
        
        // Reconnect if needed
        if (!MailService.instance.client.isConnected) {
          await MailService.instance.connect();
          if (widget.mailbox != null) {
            await MailService.instance.client.selectMailbox(widget.mailbox!);
          }
        }
      }
    }
    
    throw Exception("Failed to fetch after $maxRetries retries");
  }

  Future<void> _preloadSmallAttachments() async {
    for (final attachment in _attachments) {
      final size = attachment.size ?? 0;
      if (size > 0 && size < 512 * 1024) { // Less than 512KB
        final attachmentKey = '${_messageKey}_${attachment.fetchId}';
        if (!_attachmentDataCache.containsKey(attachmentKey)) {
          try {
            final data = await _fetchAttachmentData(attachment);
            if (data != null) {
              _attachmentDataCache[attachmentKey] = data;
            }
          } catch (e) {
            // Ignore preload errors
            if (kDebugMode) {
              print('Preload failed for attachment: $e');
            }
          }
        }
      }
    }
  }

  Future<Uint8List?> _fetchAttachmentData(MimePart attachment) async {
    if (_cachedMessage == null || attachment.fetchId == null) return null;
    
    final attachmentKey = '${_messageKey}_${attachment.fetchId}';
    
    // Check cache first
    if (_attachmentDataCache.containsKey(attachmentKey)) {
      return _attachmentDataCache[attachmentKey];
    }

    try {
      final data = await MailService.instance.client.fetchMessagePart(_cachedMessage!, attachment.fetchId!);
      _attachmentDataCache[attachmentKey] = data;
      return data;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to fetch attachment data: $e');
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppTheme.errorColor,
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.errorColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadMessageContent,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_cachedMessage == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Attachments section
        if (_attachments.isNotEmpty) _buildAttachmentSection(context),
        
        // Message content
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: MimeMessageViewer(
            mimeMessage: _cachedMessage!,
            adjustHeight: true,
            blockExternalImages: true,
            preferPlainText: false,
            showMediaWidget: true,
            maxImageWidth: MediaQuery.of(context).size.width - 32,
          ),
        ),
      ],
    );
  }

  Widget _buildAttachmentSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.attach_file,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Attachments (${_attachments.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _attachments.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final attachment = _attachments[index];
              return _buildAttachmentTile(context, attachment);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentTile(BuildContext context, MimePart attachment) {
    final fileName = attachment.decodeFileName() ?? 'Unknown';
    final fileSize = _formatFileSize(attachment.size ?? 0);
    final fileIcon = _getFileIcon(fileName);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        child: Icon(
          fileIcon,
          color: Theme.of(context).primaryColor,
        ),
      ),
      title: Text(
        fileName,
        style: const TextStyle(fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(fileSize),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadAttachment(attachment),
            tooltip: 'Download',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareAttachment(attachment),
            tooltip: 'Share',
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }

  Future<void> _downloadAttachment(MimePart attachment) async {
    try {
      final data = await _fetchAttachmentData(attachment);
      if (data == null) {
        throw Exception('Failed to fetch attachment data');
      }

      // Request storage permission
      if (await Permission.storage.request().isGranted) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = attachment.decodeFileName() ?? 'attachment';
        final file = File('${directory.path}/$fileName');
        
        await file.writeAsBytes(data);
        
        Get.snackbar(
          'Download Complete',
          'Attachment saved to ${file.path}',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } else {
        throw Exception('Storage permission denied');
      }
    } catch (e) {
      Get.snackbar(
        'Download Failed',
        'Failed to download attachment: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _shareAttachment(MimePart attachment) async {
    try {
      final data = await _fetchAttachmentData(attachment);
      if (data == null) {
        throw Exception('Failed to fetch attachment data');
      }

      final directory = await getTemporaryDirectory();
      final fileName = attachment.decodeFileName() ?? 'attachment';
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsBytes(data);
      
      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      Get.snackbar(
        'Share Failed',
        'Failed to share attachment: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  // Static methods for cache management
  static void clearCache() {
    _contentCache.clear();
    _attachmentCache.clear();
    _attachmentDataCache.clear();
  }

  static void cleanupCache() {
    // Keep only last 50 messages in cache
    if (_contentCache.length > 50) {
      final keys = _contentCache.keys.toList();
      final keysToRemove = keys.take(keys.length - 50);
      for (final key in keysToRemove) {
        _contentCache.remove(key);
        _attachmentCache.remove(key);
        _attachmentDataCache.removeWhere((k, v) => k.startsWith(key));
      }
    }
  }

  @override
  void dispose() {
    // Clean up cache periodically
    if (_contentCache.length > 100) {
      cleanupCache();
    }
    super.dispose();
  }
}

