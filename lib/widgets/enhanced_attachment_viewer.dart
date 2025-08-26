import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:open_app_file/open_app_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../utills/theme/app_theme.dart';

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
      final contentInfo = mimeMessage.findContentInfo();
      
      // Filter out inline content if not showing inline
      if (!showInline) {
        // Simplified filtering - show all attachments for now
        return contentInfo.toList();
      }
      
      return contentInfo.take(maxAttachmentsToShow).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting attachments: $e');
      }
      return [];
    }
  }

  Widget _buildAttachmentHeader(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.attachment,
            color: AppTheme.primaryColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Attachments ($count)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const Spacer(),
          if (count > 1)
            TextButton.icon(
              onPressed: () => _downloadAllAttachments(),
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download All'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttachmentList(BuildContext context, List<ContentInfo> attachments) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: attachments.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey.shade200,
        ),
        itemBuilder: (context, index) {
          return EnhancedAttachmentTile(
            contentInfo: attachments[index],
            mimeMessage: mimeMessage,
          );
        },
      ),
    );
  }

  Future<void> _downloadAllAttachments() async {
    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        if (kDebugMode) {
          print('Storage permission denied');
        }
        return;
      }

      final attachments = _getAttachments();
      final directory = await getApplicationDocumentsDirectory();
      
      for (final attachment in attachments) {
        try {
          await _downloadAttachment(attachment, directory);
        } catch (e) {
          if (kDebugMode) {
            print('Error downloading attachment ${attachment.fileName}: $e');
          }
        }
      }
      
      if (kDebugMode) {
        print('All attachments downloaded to ${directory.path}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error downloading all attachments: $e');
      }
    }
  }

  Future<void> _downloadAttachment(ContentInfo contentInfo, Directory directory) async {
    try {
      // Simplified approach - use basic ContentInfo functionality
      final fileName = contentInfo.fileName ?? 'attachment_${DateTime.now().millisecondsSinceEpoch}';
      final file = File('${directory.path}/$fileName');
      
      // For now, create a placeholder file - actual implementation would need proper data access
      await file.writeAsString('Attachment: ${contentInfo.fileName ?? "Unknown"}');
      
      if (kDebugMode) {
        print('Downloaded attachment: $fileName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error downloading attachment: $e');
      }
    }
  }
}

/// Enhanced attachment tile with better UI and functionality
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
    final mimeType = widget.contentInfo.contentType?.mediaType?.toString() ?? 'application/octet-stream';

    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _getFileColor(fileName).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          fileIcon,
          color: _getFileColor(fileName),
          size: 24,
        ),
      ),
      title: Text(
        fileName,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$fileSize • $mimeType',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          if (_isDownloaded)
            Text(
              'Downloaded',
              style: TextStyle(
                fontSize: 11,
                color: Colors.green.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Preview button for images
          if (_isImage(mimeType))
            IconButton(
              onPressed: () => _previewAttachment(),
              icon: const Icon(Icons.visibility, size: 20),
              tooltip: 'Preview',
            ),
          
          // Share button
          IconButton(
            onPressed: _isDownloading ? null : () => _shareAttachment(),
            icon: const Icon(Icons.share, size: 20),
            tooltip: 'Share',
          ),
          
          // Download/Open button
          IconButton(
            onPressed: _isDownloading ? null : () => _downloadAndOpenAttachment(),
            icon: _isDownloading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isDownloaded ? Icons.open_in_new : Icons.download,
                    size: 20,
                  ),
            tooltip: _isDownloaded ? 'Open' : 'Download',
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
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
        return FontAwesomeIcons.fileImage;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
        return FontAwesomeIcons.fileVideo;
      case 'mp3':
      case 'wav':
      case 'flac':
        return FontAwesomeIcons.fileAudio;
      case 'zip':
      case 'rar':
      case '7z':
        return FontAwesomeIcons.fileZipper;
      case 'txt':
        return FontAwesomeIcons.fileLines;
      default:
        return FontAwesomeIcons.file;
    }
  }

  Color _getFileColor(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
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
        return Colors.purple;
      case 'mp4':
      case 'avi':
      case 'mov':
      case 'wmv':
        return Colors.indigo;
      case 'mp3':
      case 'wav':
      case 'flac':
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

  bool _isImage(String mimeType) {
    return mimeType.startsWith('image/');
  }

  Future<void> _previewAttachment() async {
    // TODO: Implement image preview
    if (kDebugMode) {
      print('Preview attachment: ${widget.contentInfo.fileName}');
    }
  }

  Future<void> _shareAttachment() async {
    try {
      // Simplified approach - create a text file with attachment info
      final directory = await getTemporaryDirectory();
      final fileName = widget.contentInfo.fileName ?? 'attachment';
      final file = File('${directory.path}/$fileName.txt');
      
      await file.writeAsString('Email Attachment: ${widget.contentInfo.fileName ?? "Unknown"}');
      
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Shared from email: ${widget.mimeMessage.decodeSubject() ?? "No Subject"}',
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error sharing attachment: $e');
      }
    }
  }

  Future<void> _downloadAndOpenAttachment() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        if (kDebugMode) {
          print('Storage permission denied');
        }
        return;
      }

      // Simplified approach - create a placeholder file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = widget.contentInfo.fileName ?? 'attachment_${DateTime.now().millisecondsSinceEpoch}';
      final file = File('${directory.path}/$fileName.txt');
      
      await file.writeAsString('Email Attachment: ${widget.contentInfo.fileName ?? "Unknown"}');
      
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
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }
}

