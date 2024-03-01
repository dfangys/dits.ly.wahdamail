import 'dart:developer';
import 'dart:io';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../services/mail_service.dart';

class MailAttachments extends StatelessWidget {
  const MailAttachments({super.key, required this.message});
  final MimeMessage message;
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: MailService.instance.client.fetchMessageContents(message),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          if (snapshot.data!.findContentInfo().isNotEmpty) {
            return Column(
              children: [
                for (var c in snapshot.data!.findContentInfo())
                  ListTile(
                    dense: true,
                    leading: Icon(getAttachmentIcon(c.fileName)),
                    title: Text(
                      c.fileName.toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () async {
                      try {
                        MimePart? mimePart = snapshot.data!.getPart(c.fetchId);
                        if (mimePart != null) {
                          Uint8List? uint8List = mimePart.decodeContentBinary();
                          if (uint8List != null) {
                            await saveFile(
                              context,
                              uint8List,
                              c.fileName ?? 'file',
                            );
                          }
                        }
                      } catch (e) {
                        log(e.toString());
                      } finally {}
                    },
                  ),
              ],
            );
          } else {
            return const SizedBox.shrink();
          }
        } else if (snapshot.hasError) {
          return Center(
            child: Text('Attachment Error: ${snapshot.error}'),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Future<bool> saveFile(
      BuildContext context, Uint8List uint8List, String fileName) async {
    late Directory? directory;
    try {
      if (Platform.isAndroid) {
        if (await requestPermission(Permission.storage)) {
          directory = await getApplicationCacheDirectory();
          String newPath = "";
          List<String> paths = directory.path.split("/");
          for (int x = 1; x < paths.length; x++) {
            String folder = paths[x];
            if (folder != "Android") {
              newPath += "/$folder";
            } else {
              break;
            }
          }
          newPath = "$newPath/NetxMail";
          directory = Directory(newPath);
        } else {
          return false;
        }
      } else {
        if (await requestPermission(Permission.photos)) {
          directory = await getTemporaryDirectory();
        } else {
          return false;
        }
      }

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      if (await directory.exists()) {
        File file = File('${directory.path}/$fileName');
        await file.writeAsBytes(uint8List);
        final result = await Share.shareXFiles(
          [XFile(file.path)],
          text: 'I am sharing this',
        );
        if (result.status == ShareResultStatus.success) {
          if (kDebugMode) {
            print('Thank you for sharing the picture!');
          }
        }
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        printError(info: e.toString());
      }
      return false;
    }
  }

  Future<bool> requestPermission(Permission permission) async {
    return true;
    // if (await permission.isGranted) {
    //   return true;
    // } else {
    //   var result = await permission.request();
    //   if (result == PermissionStatus.granted ||
    //       result == PermissionStatus.limited) {
    //     return true;
    //   }
    // }
    // return false;
  }
}

IconData getAttachmentIcon(String? file) {
  String ext = file!.split(".").last.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
    case 'jfif':
    case 'pjpeg':
    case 'pjp':
    case 'png':
    case 'sgv':
    case 'gif':
      return Icons.image;
    case 'pdf':
      return Icons.picture_as_pdf_outlined;
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
      return Icons.attach_file;
  }
}
