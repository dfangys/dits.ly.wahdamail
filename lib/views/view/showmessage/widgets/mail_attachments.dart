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
import '../../../../services/mail_service.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

class MailAttachments extends StatefulWidget {
  const MailAttachments({super.key, required this.message});
  final MimeMessage message;

  @override
  State<MailAttachments> createState() => _MailAttachmentsState();
}

class _MailAttachmentsState extends State<MailAttachments> {
  late Future<MimeMessage> _messageFuture;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadMessage();
  }

  Future<void> _loadMessage() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Use the caching mechanism to avoid redundant fetches
      _messageFuture = MailService.instance.getMessageWithCaching(widget.message);

      // Pre-fetch to catch any errors
      await _messageFuture;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
      log('Error loading message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading message content...',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red.shade700,
              ),
              const SizedBox(height: 16),
              Text(
                'Error loading message',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadMessage,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FutureBuilder<MimeMessage>(
      future: _messageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondaryColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _loadMessage,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Center(
            child: Text(
              'No message data available',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondaryColor,
              ),
            ),
          );
        }

        final message = snapshot.data!;
        final attachments = message.findContentInfo();

        // Fixed layout to avoid unbounded height constraints
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Use min to avoid unbounded height issues
          children: [
            // Show attachments section only if there are attachments
            if (attachments.isNotEmpty) ...[
              Container(
                margin: EdgeInsets.only(bottom: 16, top: isTablet ? 8 : 4),
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 16 : 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with animation
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, (1 - value) * 10),
                            child: child,
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.attachment_rounded,
                            size: isTablet ? 20 : 18,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Attachments (${attachments.length})',
                            style: TextStyle(
                              fontSize: isTablet ? 16 : 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),

                    // Attachments grid/list based on device size
                    isTablet
                        ? _buildAttachmentsGrid(attachments, message)
                        : _buildAttachmentsList(attachments, message),
                  ],
                ),
              ),
            ],

            // Message content viewer with improved container
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              height: MediaQuery.of(context).size.height * (isTablet ? 0.65 : 0.6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: MimeMessageViewer(
                  mimeMessage: message,
                  // No mailtoDelegate for compatibility
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAttachmentsGrid(List<ContentInfo> attachments, MimeMessage message) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: attachments.length,
      itemBuilder: (context, index) {
        final attachment = attachments[index];
        return AttachmentGridTile(
          message: message,
          attachment: attachment,
        );
      },
    );
  }

  Widget _buildAttachmentsList(List<ContentInfo> attachments, MimeMessage message) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: attachments.length,
      itemBuilder: (context, index) {
        final attachment = attachments[index];
        return AttachmentTile(
          message: message,
          attachment: attachment,
        );
      },
    );
  }
}

class AttachmentGridTile extends StatefulWidget {
  final MimeMessage message;
  final ContentInfo attachment;

  const AttachmentGridTile({
    super.key,
    required this.message,
    required this.attachment,
  });

  @override
  State<AttachmentGridTile> createState() => _AttachmentGridTileState();
}

class _AttachmentGridTileState extends State<AttachmentGridTile> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _errorMessage;

  Future<void> _downloadAttachment() async {
    try {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
        _errorMessage = null;
      });

      // Get the MIME part
      final mimePart = widget.message.getPart(widget.attachment.fetchId);
      if (mimePart == null) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Attachment not found';
        });
        return;
      }

      // Decode content
      final content = mimePart.decodeContentBinary();
      if (content == null) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Failed to decode attachment';
        });
        return;
      }

      // Update progress
      setState(() {
        _downloadProgress = 0.5;
      });

      // Save file
      final success = await _saveFile(content, widget.attachment.fileName ?? 'file');

      setState(() {
        _isDownloading = false;
        _downloadProgress = 1.0;
        if (!success) {
          _errorMessage = 'Failed to save file';
        }
      });
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _errorMessage = e.toString();
      });
      log('Error downloading attachment: $e');
    }
  }

  Future<bool> _saveFile(Uint8List data, String fileName) async {
    try {
      // For iOS, use the documents directory which is accessible
      if (Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(data);

        if (kDebugMode) {
          print('File saved to: $filePath');
        }

        // Open the file
        final result = await OpenAppFile.open(filePath);
        if (kDebugMode) {
          print('Open file result: $result');
        }

        return true;
      }
      // For Android, use external storage
      else if (Platform.isAndroid) {
        // Request storage permission
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          if (kDebugMode) {
            print('Storage permission denied');
          }
          return false;
        }

        // Get the downloads directory
        final directory = await getExternalStorageDirectory();
        if (directory == null) {
          if (kDebugMode) {
            print('Could not access external storage');
          }
          return false;
        }

        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(data);

        if (kDebugMode) {
          print('File saved to: $filePath');
        }

        // Open the file
        final result = await OpenAppFile.open(filePath);
        if (kDebugMode) {
          print('Open file result: $result');
        }

        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving file: $e');
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isImage = isImageFile(widget.attachment.fileName);

    return InkWell(
      onTap: _isDownloading ? null : _downloadAttachment,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // File icon or progress indicator
            if (_isDownloading)
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: _downloadProgress > 0 ? _downloadProgress : null,
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                    if (_downloadProgress > 0)
                      Text(
                        '${(_downloadProgress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                  ],
                ),
              )
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isImage
                      ? AppTheme.primaryColor.withOpacity(0.1)
                      : AppTheme.attachmentIconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  getAttachmentIcon(widget.attachment.fileName),
                  size: 24,
                  color: isImage
                      ? AppTheme.primaryColor
                      : AppTheme.attachmentIconColor,
                ),
              ),

            const SizedBox(height: 8),

            // File name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                widget.attachment.fileName ?? 'Unnamed',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Error message if any
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Error',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AttachmentTile extends StatefulWidget {
  final MimeMessage message;
  final ContentInfo attachment;

  const AttachmentTile({
    super.key,
    required this.message,
    required this.attachment,
  });

  @override
  State<AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends State<AttachmentTile> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _errorMessage;

  Future<void> _downloadAttachment() async {
    try {
      setState(() {
        _isDownloading = true;
        _downloadProgress = 0.0;
        _errorMessage = null;
      });

      // Get the MIME part
      final mimePart = widget.message.getPart(widget.attachment.fetchId);
      if (mimePart == null) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Attachment not found';
        });
        return;
      }

      // Decode content
      final content = mimePart.decodeContentBinary();
      if (content == null) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Failed to decode attachment';
        });
        return;
      }

      // Update progress
      setState(() {
        _downloadProgress = 0.5;
      });

      // Save file
      final success = await _saveFile(content, widget.attachment.fileName ?? 'file');

      setState(() {
        _isDownloading = false;
        _downloadProgress = 1.0;
        if (!success) {
          _errorMessage = 'Failed to save file';
        }
      });
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _errorMessage = e.toString();
      });
      log('Error downloading attachment: $e');
    }
  }

  // Fixed file saving implementation
  Future<bool> _saveFile(Uint8List data, String fileName) async {
    try {
      // For iOS, use the documents directory which is accessible
      if (Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(data);

        if (kDebugMode) {
          print('File saved to: $filePath');
        }

        // Open the file
        final result = await OpenAppFile.open(filePath);
        if (kDebugMode) {
          print('Open file result: $result');
        }

        return true;
      }
      // For Android, use external storage
      else if (Platform.isAndroid) {
        // Request storage permission
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          if (kDebugMode) {
            print('Storage permission denied');
          }
          return false;
        }

        // Get the downloads directory
        final directory = await getExternalStorageDirectory();
        if (directory == null) {
          if (kDebugMode) {
            print('Could not access external storage');
          }
          return false;
        }

        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(data);

        if (kDebugMode) {
          print('File saved to: $filePath');
        }

        // Open the file
        final result = await OpenAppFile.open(filePath);
        if (kDebugMode) {
          print('Open file result: $result');
        }

        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error saving file: $e');
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isImage = isImageFile(widget.attachment.fileName);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        onTap: _isDownloading ? null : _downloadAttachment,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              // File icon or progress indicator
              if (_isDownloading)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _downloadProgress > 0 ? _downloadProgress : null,
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                      ),
                      if (_downloadProgress > 0)
                        Text(
                          '${(_downloadProgress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                    ],
                  ),
                )
              else
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isImage
                        ? AppTheme.primaryColor.withOpacity(0.1)
                        : AppTheme.attachmentIconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    getAttachmentIcon(widget.attachment.fileName),
                    size: 20,
                    color: isImage
                        ? AppTheme.primaryColor
                        : AppTheme.attachmentIconColor,
                  ),
                ),

              const SizedBox(width: 16),

              // File details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.attachment.fileName ?? 'Unnamed attachment',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Download icon
              if (!_isDownloading)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.download_rounded,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                ),
            ],
          ),
        ),
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
      return Icons.image_rounded;
    case 'pdf':
      return Icons.picture_as_pdf_rounded;
    case 'pptx':
    case 'pptm':
    case 'ppt':
      return FontAwesomeIcons.solidFilePowerpoint;
    case 'zip':
    case 'rar':
      return FontAwesomeIcons.fileZipper;
    case 'docx':
    case 'doc':
    case 'odt':
      return FontAwesomeIcons.fileWord;
    case 'txt':
    case 'rtf':
    case 'tex':
      return FontAwesomeIcons.textWidth;
    case 'xls':
    case 'xlsx':
    case 'xlsm':
    case 'xlsb':
    case 'xltx':
      return FontAwesomeIcons.fileExcel;
    case 'mp3':
    case 'mpeg-1':
    case 'aac ':
    case 'flac':
    case 'alac':
    case 'wav':
    case 'aiff':
    case 'dsd':
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
    default:
      return Icons.attach_file_rounded;
  }
}

bool isImageFile(String? file) {
  if (file == null) return false;

  String ext = file.split(".").last.toLowerCase();
  return ['jpg', 'jpeg', 'jfif', 'pjpeg', 'pjp', 'png', 'sgv', 'gif'].contains(ext);
}
