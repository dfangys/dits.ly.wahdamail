import 'dart:developer';
import 'dart:io';
import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail_flutter/enough_mail_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/views/view/inbox/widgets/inbox_app_bar.dart';
import 'package:wahda_bank/views/view/inbox/widgets/inbox_bottom_navbar.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';

class ShowMessage extends StatelessWidget {
  const ShowMessage({super.key, required this.message});
  final MimeMessage message;

  String get name {
    if (message.from != null && message.from!.isEmpty) {
      return message.from!.first.personalName ?? message.from!.first.email;
    } else if (message.fromEmail == null) {
      return "Unknown";
    }
    return message.fromEmail ?? "Unknow";
  }

  String get date {
    return DateFormat("EEE hh:mm a").format(
      message.decodeDate() ?? DateTime.now(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: InbocAppBar(indicator: false, message: message),
      ),
      bottomNavigationBar: const InboxBottomNavBar(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              child: ListTile(
                onTap: () {},
                leading: CircleAvatar(
                  backgroundColor:
                      Colors.primaries[0 % Colors.primaries.length],
                  radius: 25.0,
                  child: Text(
                    name[0],
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  (message.decodeDate() ?? DateTime.now()).toString(),
                  maxLines: 1,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            const SizedBox(height: WSizes.defaultSpace),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: FutureBuilder(
                future:
                    MailService.instance.client.fetchMessageContents(message),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    if (snapshot.data!.findContentInfo().isNotEmpty) {
                      return Row(
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
                                child: Text(c.mediaType!.text),
                              ),
                              onTap: () async {
                                try {
                                  MimePart? mimePart =
                                      snapshot.data!.getPart(c.fetchId);
                                  if (mimePart != null) {
                                    Uint8List? uint8List =
                                        mimePart.decodeContentBinary();
                                    if (uint8List != null) {
                                      bool isSaved = await saveFile(
                                        context,
                                        uint8List,
                                        c.fileName ?? 'file',
                                      );
                                      print("Svaed $isSaved");
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
              ),
            ),
            MimeMessageDownloader(
              mimeMessage: message,
              mailClient: MailService.instance.client,
              adjustHeight: true,
              markAsSeen: true,
            ),
          ],
        ),
      ),
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
