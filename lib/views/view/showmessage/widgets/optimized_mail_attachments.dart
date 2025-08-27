import 'dart:typed_data';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:share_plus/share_plus.dart';

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
  List<ContentInfo> _attachments = [];
  bool _isLoading = true;
  String? _error;
  late String _messageKey;
  
  // Cache for attachments
  static final Map<String, List<ContentInfo>> _attachmentCache = {};
  static final Map<String, Uint8List> _attachmentDataCache = {};
  
  // Services
  final MailService _mailService = Get.find<MailService>();

  @override
  void initState() {
    super.initState();
    _messageKey = _generateMessageKey();
    _loadAttachments();
  }

  String _generateMessageKey() {
    return '${widget.message.uid ?? widget.message.sequenceId ?? widget.message.hashCode}';
  }

  Future<void> _loadAttachments() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Check cache first
      if (_attachmentCache.containsKey(_messageKey)) {
        setState(() {
          _attachments = _attachmentCache[_messageKey]!;
          _isLoading = false;
        });
        return;
      }

      // Ensure we have the full message content
      MimeMessage messageContent = widget.message;
      if (!widget.message.hasAttachments()) {
        // Try to fetch full content if not available
        try {
          messageContent = await _mailService.client.fetchMessageContents(widget.message);
        } catch (e) {
          // If fetch fails, use original message
          messageContent = widget.message;
        }
      }
      
      // Extract attachments
      _attachments = messageContent.findContentInfo(disposition: ContentDisposition.attachment);
      _attachmentCache[_messageKey] = _attachments;
      
      // Preload small attachments in background
      _preloadSmallAttachments();
      
    } catch (e) {
      setState(() {
        _error = 'Failed to load attachments: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _preloadSmallAttachments() {
    for (final attachment in _attachments) {
      final size = attachment.size ?? 0;
      if (size > 0 && size < 512 * 1024) { // Preload files smaller than 512KB
        _fetchAttachmentData(attachment).catchError((e) {
          // Ignore preload errors
          return null;
        });
      }
    }
  }

  Future<Uint8List?> _fetchAttachmentData(ContentInfo attachment) async {
    try {
      // Check cache first
      final cacheKey = _generateAttachmentKey(attachment);
      if (_attachmentDataCache.containsKey(cacheKey)) {
        return _attachmentDataCache[cacheKey];
      }

      // Ensure correct mailbox is selected
      if (widget.mailbox != null && 
          _mailService.client.selectedMailbox?.path != widget.mailbox!.path) {
        await _mailService.client.selectMailbox(widget.mailbox!);
      }

      // Fetch the attachment part
      final part = await _mailService.client.fetchMessagePart(
        widget.message, 
        attachment.fetchId,
      );
      
      final contentTransferEncoding = part.getHeaderValue('content-transfer-encoding');
      final data = part.mimeData!.decodeBinary(contentTransferEncoding);
      // Cache the data
      _attachmentDataCache[cacheKey] = data;
      return data;
    } catch (e) {
      throw Exception('Failed to fetch attachment: $e');
    }
  }

  String _generateAttachmentKey(ContentInfo attachment) {
    return 'attachment_${_messageKey}_${attachment.fetchId}';
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
                color: Colors.red,
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAttachments,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.attachment,
                  color: Colors.grey[600],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Attachments (${_attachments.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _attachments.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final attachment = _attachments[index];
              return _AttachmentTile(
                attachment: attachment,
                onDownload: () => _downloadAttachment(attachment),
                onShare: () => _shareAttachment(attachment),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAttachment(ContentInfo attachment) async {
    try {
      final data = await _fetchAttachmentData(attachment);
      if (data != null) {
        // Show success message
        Get.snackbar(
          'Success',
          'Attachment downloaded successfully',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        throw Exception('No data received');
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to download attachment: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _shareAttachment(ContentInfo attachment) async {
    try {
      final data = await _fetchAttachmentData(attachment);
      if (data != null) {
        final filename = attachment.contentDisposition?.filename ?? 
                        attachment.contentType?.parameters['name'] ?? 
                        'attachment';
        // Create a temporary file and share it
        // ignore: deprecated_member_use
        await Share.shareXFiles([
          XFile.fromData(
            data,
            name: filename,
            mimeType: attachment.mediaType?.text,
          ),
        ]);
      } else {
        throw Exception('No data to share');
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to share attachment: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }
}

class _AttachmentTile extends StatelessWidget {
  const _AttachmentTile({
    required this.attachment,
    required this.onDownload,
    required this.onShare,
  });

  final ContentInfo attachment;
  final VoidCallback onDownload;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final filename = attachment.contentDisposition?.filename ?? 
                    attachment.contentType?.parameters['name'] ?? 
                    'Unknown file';
    final size = attachment.size;
    final sizeText = size != null ? _formatFileSize(size) : 'Unknown size';

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.blue[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _getFileIcon(filename),
          color: Colors.blue[700],
          size: 20,
        ),
      ),
      title: Text(
        filename,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        sizeText,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 12,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: onDownload,
            tooltip: 'Download',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: onShare,
            tooltip: 'Share',
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  IconData _getFileIcon(String filename) {
    final extension = filename.split('.').last.toLowerCase();
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
      case 'flac':
        return Icons.audio_file;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }
}

