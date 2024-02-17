import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
                  InkWell(
                    child: Container(
                      width: 50,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.grey,
                          width: 1,
                        ),
                      ),
                      child: Text(c.fileName.toString()),
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
          }
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
          log("message");
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
    if (await permission.isGranted) {
      return true;
    } else {
      var result = await permission.request();
      if (result == PermissionStatus.granted ||
          result == PermissionStatus.limited) {
        return true;
      }
    }
    return false;
  }
}
