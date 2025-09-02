import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:open_app_file/open_app_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wahda_bank/services/attachment_fetcher.dart';
import 'package:wahda_bank/services/mime_utils.dart';

/// Enhanced attachment viewer implementing enough_mail best practices
class EnhancedAttachmentViewer extends StatelessWidget {
  const EnhancedAttachmentViewer({
    super.key,
    required this.mimeMessage,
    this.showInline = true,
    this.maxAttachmentsToShow = 10,
  });

  final MimeMessage mimeMessage;
  final bool showInline;
  final int maxAttachmentsToShow;

  @override
  Widget build(BuildContext context) {
    final attachments = _getAttachments();

    if (attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAttachmentHeader(context, attachments.length),
        _buildAttachmentList(context, attachments),
      ],
    );
  }

  List<ContentInfo> _getAttachments() {
    try {
      // Prefer only real attachments when inline display is disabled
      final contentInfo =
          showInline
              ? mimeMessage.findContentInfo()
              : mimeMessage.findContentInfo(
                disposition: ContentDisposition.attachment,
              );

      return contentInfo.toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting attachments: $e');
      }
      return [];
    }
  }

  Widget _buildAttachmentHeader(BuildContext context, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.attach_file,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Attachments ($count)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentList(
    BuildContext context,
    List<ContentInfo> attachments,
  ) {
    final displayAttachments = attachments.take(maxAttachmentsToShow).toList();

    return Column(
      children: [
        ...displayAttachments.map(
          (attachment) => EnhancedAttachmentTile(
            key: ValueKey('${attachment.fetchId}_${attachment.fileName ?? ''}'),
            contentInfo: attachment,
            mimeMessage: mimeMessage,
          ),
        ),
        if (attachments.length > maxAttachmentsToShow)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '... and ${attachments.length - maxAttachmentsToShow} more attachments',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// Individual attachment tile with download and preview capabilities
class EnhancedAttachmentTile extends StatefulWidget {
  const EnhancedAttachmentTile({
    super.key,
    required this.contentInfo,
    required this.mimeMessage,
  });

  final ContentInfo contentInfo;
  final MimeMessage mimeMessage;

  @override
  State<EnhancedAttachmentTile> createState() => _EnhancedAttachmentTileState();
}

class _EnhancedAttachmentTileState extends State<EnhancedAttachmentTile> {
  bool _isDownloading = false;
  bool _isDownloaded = false;

  @override
  Widget build(BuildContext context) {
    final fileName = widget.contentInfo.fileName ?? 'Unknown';
    final fileSize = _formatFileSize(widget.contentInfo.size);
    final fileIcon = _getFileIcon(fileName);
    final mimeType = MimeUtils.inferMimeType(
      fileName,
      contentType: widget.contentInfo.contentType?.mediaType.toString(),
    );

    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _getFileColor(fileName).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(fileIcon, color: _getFileColor(fileName), size: 24),
      ),
      title: Text(
        fileName,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fileSize,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          Text(
            mimeType,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_canPreview(fileName))
            IconButton(
              icon: const Icon(Icons.visibility, size: 20),
              onPressed: _isDownloading ? null : _previewAttachment,
              tooltip: 'Preview',
            ),
          IconButton(
            icon: const Icon(Icons.share, size: 20),
            onPressed: _isDownloading ? null : _shareAttachment,
            tooltip: 'Share',
          ),
          IconButton(
            icon:
                _isDownloading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : Icon(
                      _isDownloaded ? Icons.open_in_new : Icons.download,
                      size: 20,
                    ),
            onPressed: _isDownloading ? null : _downloadAndOpenAttachment,
            tooltip: _isDownloaded ? 'Open' : 'Download',
          ),
        ],
      ),
    );
  }

  bool _canPreview(String fileName) {
    final mime = MimeUtils.inferMimeType(
      fileName,
      contentType: widget.contentInfo.contentType?.mediaType.toString(),
    );
    return MimeUtils.canPreviewInApp(mime, fileName);
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;

    switch (extension) {
      case 'pdf':
        return FontAwesomeIcons.filePdf;
      case 'doc':
      case 'docx':
        return FontAwesomeIcons.fileWord;
      case 'xls':
      case 'xlsx':
        return FontAwesomeIcons.fileExcel;
      case 'ppt':
      case 'pptx':
        return FontAwesomeIcons.filePowerpoint;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return FontAwesomeIcons.fileImage;
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
        return FontAwesomeIcons.fileVideo;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'm4a':
        return FontAwesomeIcons.fileAudio;
      case 'zip':
      case 'rar':
      case '7z':
        return FontAwesomeIcons.fileZipper;
      case 'txt':
      case 'md':
        return FontAwesomeIcons.fileLines;
      case 'html':
      case 'htm':
        return FontAwesomeIcons.fileCode;
      default:
        return FontAwesomeIcons.file;
    }
  }

  Color _getFileColor(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;

    switch (extension) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return Colors.purple;
      case 'mp4':
      case 'mov':
      case 'avi':
      case 'mkv':
        return Colors.indigo;
      case 'mp3':
      case 'wav':
      case 'aac':
      case 'm4a':
        return Colors.teal;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return 'Unknown size';

    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var suffixIndex = 0;

    while (size >= 1024 && suffixIndex < suffixes.length - 1) {
      size /= 1024;
      suffixIndex++;
    }

    return '${size.toStringAsFixed(size < 10 ? 1 : 0)} ${suffixes[suffixIndex]}';
  }

  Future<Uint8List?> _getAttachmentData() async {
    return AttachmentFetcher.fetchBytes(
      message: widget.mimeMessage,
      content: widget.contentInfo,
    );
  }

  Future<void> _previewAttachment() async {
    try {
      final data = await _getAttachmentData();
      if (data == null || data.isEmpty) {
        throw Exception('No attachment data available for preview');
      }
      // Create temporary file for preview
      final directory = await getTemporaryDirectory();
      final fileName =
          widget.contentInfo.fileName ??
          'attachment_${DateTime.now().millisecondsSinceEpoch}';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(data);
      // Open the file for preview
      final result = await OpenAppFile.open(file.path);
      if (kDebugMode) {
        print('Preview attachment result: ${result.type} - ${result.message}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error previewing attachment: $e');
      }
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to preview attachment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareAttachment() async {
    try {
      final data = await _getAttachmentData();
      if (data == null || data.isEmpty) {
        throw Exception('No attachment data available for sharing');
      }
      // Create temporary file for sharing
      final directory = await getTemporaryDirectory();
      final fileName =
          widget.contentInfo.fileName ??
          'attachment_${DateTime.now().millisecondsSinceEpoch}';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(data);
      // Use SharePlus
      // ignore: deprecated_member_use
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Sharing attachment: $fileName');
      if (kDebugMode) {
        print('Shared attachment: $fileName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sharing attachment: $e');
      }
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to share attachment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadAndOpenAttachment() async {
    setState(() {
      _isDownloading = true;
    });

    try {
      // Request storage permission (Android); iOS ignores this gracefully
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        if (kDebugMode) {
          print('Storage permission denied');
        }
        return;
      }

      final data = await _getAttachmentData();
      if (data == null || data.isEmpty) {
        throw Exception('No attachment data available');
      }

      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          widget.contentInfo.fileName ??
          'attachment_${DateTime.now().millisecondsSinceEpoch}';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(data);

      if (kDebugMode) {
        print('Downloaded attachment: $fileName');
      }

      setState(() {
        _isDownloaded = true;
      });

      // Try to open the file
      final result = await OpenAppFile.open(file.path);
      if (kDebugMode) {
        print('File open result: ${result.type} - ${result.message}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error downloading/opening attachment: $e');
      }
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading attachment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }
}
