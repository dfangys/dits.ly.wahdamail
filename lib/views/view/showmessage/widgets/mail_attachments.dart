import 'dart:developer';
import 'dart:io';
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

class MailAttachments extends StatelessWidget {
  const MailAttachments({super.key, required this.message});
  final MimeMessage message;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: MailService.instance.client.fetchMessageContents(message),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      color: AppTheme.errorColor,
                      size: 48
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading message content: ${snapshot.error}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.errorColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Get.forceAppUpdate(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        } else if (snapshot.hasData && snapshot.data != null) {
          // First display the message content
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Message content viewer
              MimeMessageViewer(
                mimeMessage: snapshot.data!,
              ),

              // Then display attachments if any
              _buildAttachmentSection(context, snapshot.data!),
            ],
          );
        } else {
          return const Center(
            child: Text('No message content available'),
          );
        }
      },
    );
  }

  Widget _buildAttachmentSection(BuildContext context, MimeMessage mimeMessage) {
    final contentInfo = mimeMessage.findContentInfo();

    // If no attachments, don't show the section at all
    if (contentInfo.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Icon(
                Icons.attachment_rounded,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Attachments (${contentInfo.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: contentInfo.length,
          itemBuilder: (context, index) {
            final c = contentInfo[index];
            return AttachmentTile(
              contentInfo: c,
              mimeMessage: mimeMessage,
            );
          },
        ),
      ],
    );
  }
}

class AttachmentTile extends StatefulWidget {
  final ContentInfo contentInfo;
  final MimeMessage mimeMessage;

  const AttachmentTile({
    super.key,
    required this.contentInfo,
    required this.mimeMessage
  });

  @override
  State<AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends State<AttachmentTile> {
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final fileName = widget.contentInfo.fileName ?? 'Unknown file';
    final fileSize = widget.contentInfo.size != null
        ? _formatFileSize(widget.contentInfo.size!)
        : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        side: BorderSide(color: AppTheme.dividerColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        onTap: _isLoading ? null : () => _handleAttachmentTap(context),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius),
                ),
                child: Center(
                  child: Icon(
                    getAttachmentIcon(fileName),
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (fileSize.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        fileSize,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _error!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.errorColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.download_rounded),
                      onPressed: () => _handleAttachmentTap(context),
                      tooltip: 'Download',
                      color: AppTheme.primaryColor,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share_rounded),
                      onPressed: () => _handleShareAttachment(context),
                      tooltip: 'Share',
                      color: AppTheme.primaryColor,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleAttachmentTap(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      MimePart? mimePart = widget.mimeMessage.getPart(widget.contentInfo.fetchId);
      if (mimePart != null) {
        Uint8List? uint8List = mimePart.decodeContentBinary();
        if (uint8List != null) {
          final success = await saveAndOpenFile(
            context,
            uint8List,
            widget.contentInfo.fileName ?? 'file',
          );

          if (!success && mounted) {
            setState(() {
              _error = 'Failed to open file';
            });
          }
        } else {
          setState(() {
            _error = 'Could not decode file content';
          });
        }
      } else {
        setState(() {
          _error = 'Attachment not found';
        });
      }
    } catch (e) {
      log('Error opening attachment: $e');
      if (mounted) {
        setState(() {
          _error = 'Error: ${e.toString().split('\n').first}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleShareAttachment(BuildContext context) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      MimePart? mimePart = widget.mimeMessage.getPart(widget.contentInfo.fetchId);
      if (mimePart != null) {
        Uint8List? uint8List = mimePart.decodeContentBinary();
        if (uint8List != null) {
          final tempFile = await _saveTempFile(
            uint8List,
            widget.contentInfo.fileName ?? 'file',
          );

          if (tempFile != null) {
            await Share.shareXFiles(
              [XFile(tempFile.path)],
              text: 'Sharing ${widget.contentInfo.fileName}',
            );
          } else {
            setState(() {
              _error = 'Could not create temporary file';
            });
          }
        } else {
          setState(() {
            _error = 'Could not decode file content';
          });
        }
      } else {
        setState(() {
          _error = 'Attachment not found';
        });
      }
    } catch (e) {
      log('Error sharing attachment: $e');
      if (mounted) {
        setState(() {
          _error = 'Error: ${e.toString().split('\n').first}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<File?> _saveTempFile(Uint8List data, String fileName) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(data);
      return file;
    } catch (e) {
      log('Error saving temp file: $e');
      return null;
    }
  }

  String _formatFileSize(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<bool> saveAndOpenFile(
      BuildContext context, Uint8List uint8List, String fileName) async {
    try {
      // First try to save to app's cache directory (doesn't require permissions)
      final cacheDir = await getApplicationCacheDirectory();
      final appDir = Directory('${cacheDir.path}/NetxMail');

      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }

      final cacheFile = File('${appDir.path}/$fileName');
      await cacheFile.writeAsBytes(uint8List);

      // Try to open the file from cache
      try {
        await OpenAppFile.open(cacheFile.path);

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening $fileName'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
        return true;
      } catch (e) {
        log('Could not open file from cache: $e');
        // If opening fails, try to save to a more accessible location
      }

      // Try to get storage permission for a better location
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (status.isGranted || status.isLimited) {
          // On Android, try to save to Downloads folder
          Directory? downloadsDir;

          try {
            // Try to get the Downloads directory
            downloadsDir = Directory('/storage/emulated/0/Download');
            if (!await downloadsDir.exists()) {
              downloadsDir = await getExternalStorageDirectory();
            }
          } catch (e) {
            log('Error getting downloads directory: $e');
            downloadsDir = await getExternalStorageDirectory();
          }

          if (downloadsDir != null) {
            final downloadFile = File('${downloadsDir.path}/$fileName');
            await downloadFile.writeAsBytes(uint8List);

            try {
              await OpenAppFile.open(downloadFile.path);

              // Show success message
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Opening $fileName from Downloads'),
                    backgroundColor: AppTheme.successColor,
                  ),
                );
              }
              return true;
            } catch (e) {
              log('Could not open file from Downloads: $e');

              // Show file location
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('File saved to ${downloadFile.path}'),
                    backgroundColor: AppTheme.infoColor,
                    duration: const Duration(seconds: 5),
                    action: SnackBarAction(
                      label: 'OK',
                      textColor: Colors.white,
                      onPressed: () {},
                    ),
                  ),
                );
              }
              return true;
            }
          }
        } else {
          // Permission denied, show dialog with instructions
          if (context.mounted) {
            _showPermissionDeniedDialog(context, 'storage');
          }
          return false;
        }
      } else if (Platform.isIOS) {
        final status = await Permission.photos.request();
        if (status.isGranted || status.isLimited) {
          // On iOS, try to use share to save the file
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/$fileName');
          await tempFile.writeAsBytes(uint8List);

          // Use share to let the user decide where to save it
          if (context.mounted) {
            await Share.shareXFiles(
              [XFile(tempFile.path)],
              text: 'Save or open $fileName',
            );
            return true;
          }
        } else {
          // Permission denied, show dialog with instructions
          if (context.mounted) {
            _showPermissionDeniedDialog(context, 'photos');
          }
          return false;
        }
      }

      // If all else fails, just share the file
      if (context.mounted) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/$fileName');
        await tempFile.writeAsBytes(uint8List);

        await Share.shareXFiles(
          [XFile(tempFile.path)],
          text: 'Save or open $fileName',
        );
        return true;
      }

      return false;
    } catch (e) {
      log('Error saving file: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving file: ${e.toString().split('\n').first}'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
      return false;
    }
  }

  void _showPermissionDeniedDialog(BuildContext context, String permissionType) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Required'),
        content: Text(
            'To save attachments, we need permission to access your ${permissionType == 'photos' ? 'photos' : 'files'}. '
                'Please grant this permission in your device settings.'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}

IconData getAttachmentIcon(String? file) {
  if (file == null) return Icons.attach_file;

  String ext = file.split(".").last.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
    case 'jfif':
    case 'pjpeg':
    case 'pjp':
    case 'png':
    case 'sgv':
    case 'gif':
    case 'webp':
    case 'bmp':
    case 'tiff':
      return Icons.image_rounded;
    case 'pdf':
      return Icons.picture_as_pdf_rounded;
    case 'pptx':
    case 'pptm':
    case 'ppt':
      return FontAwesomeIcons.solidFilePowerpoint;
    case 'zip':
    case 'rar':
    case '7z':
    case 'tar':
    case 'gz':
      return FontAwesomeIcons.fileZipper;
    case 'docx':
    case 'doc':
    case 'odt':
      return FontAwesomeIcons.fileWord;
    case 'txt':
    case 'rtf':
    case 'tex':
    case 'md':
      return FontAwesomeIcons.fileLines;
    case 'xls':
    case 'xlsx':
    case 'xlsm':
    case 'xlsb':
    case 'xltx':
    case 'csv':
      return FontAwesomeIcons.fileExcel;
    case 'mp3':
    case 'mpeg-1':
    case 'aac':
    case 'flac':
    case 'alac':
    case 'wav':
    case 'aiff':
    case 'dsd':
    case 'ogg':
      return FontAwesomeIcons.fileAudio;
    case 'mp4':
    case 'mov':
    case 'wmv':
    case 'avi':
    case 'avchd':
    case 'flv':
    case 'mkv':
    case 'html5':
    case 'webm':
    case 'swf':
      return FontAwesomeIcons.fileVideo;
    case 'html':
    case 'htm':
    case 'css':
    case 'js':
    case 'json':
    case 'xml':
      return FontAwesomeIcons.fileCode;
    default:
      return Icons.insert_drive_file_rounded;
  }
}
