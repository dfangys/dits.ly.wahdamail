import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:wahda_bank/views/compose/compose.dart';
import 'package:wahda_bank/widgets/search/search.dart';

class MailMetaTile extends StatelessWidget {
  const MailMetaTile({super.key, required this.message, required this.isShow});
  final MimeMessage message;
  final ValueNotifier<bool> isShow;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: isShow,
      builder: (context, value, child) => AnimatedCrossFade(
        firstChild: const SizedBox.shrink(),
        secondChild: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            child: Column(
              children: [
                buildMailInfo(
                  "From",
                  message.from != null
                      ? message.from!.map((e) => e.email).toList()
                      : [],
                ),
                buildMailInfo(
                  "To",
                  message.to != null
                      ? message.to!.map((e) => e.email).toList()
                      : [],
                ),
                buildMailInfo(
                  "Cc",
                  message.cc != null
                      ? message.cc!.map((e) => e.email).toList()
                      : [],
                ),
                buildMailInfo(
                  "Bcc",
                  message.bcc != null
                      ? message.bcc!.map((e) => e.email).toList()
                      : [],
                ),
                buildMailInfo(
                  "Time",
                  [
                    DateFormat().format(
                      message.decodeDate() ?? DateTime.now(),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
        crossFadeState:
            value ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: const Duration(milliseconds: 500),
        firstCurve: Curves.bounceOut,
      ),
    );
  }
}

Widget buildMailInfo(String title, List<String> data) {
  if (data.isEmpty) return const SizedBox.shrink();
  data.join(",");
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            "$title :",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (title.startsWith('Time')) {
                return;
              }
              showCupertinoModalPopup(
                context: Get.context!,
                builder: (context) => CupertinoActionSheet(
                  message: Text(data.join(' ')),
                  actions: [
                    CupertinoActionSheetAction(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(
                          text: data.join(' '),
                        ));
                        Navigator.pop(context);
                      },
                      child: const Text("Copy"),
                    ),
                    CupertinoActionSheetAction(
                      onPressed: () {
                        Get.back();
                        Get.to(() => const ComposeScreen(), arguments: {
                          "to": data.join(' '),
                        });
                      },
                      child: Text("new_message".tr),
                    ),
                    CupertinoActionSheetAction(
                      onPressed: () {
                        Get.back();
                        Get.to(() => SearchView(), arguments: {
                          "terms": data.join(' '),
                        });
                      },
                      child: Text("search".tr),
                    ),
                  ],
                  cancelButton: CupertinoActionSheetAction(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("Cancel"),
                  ),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...data.map((e) => Text("$e${data.last == e ? "" : ","}"))
              ],
            ),
          ),
        )
      ],
    ),
  );
}
