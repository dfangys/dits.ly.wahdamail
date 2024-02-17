import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

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
            onLongPress: () {
              Clipboard.setData(ClipboardData(
                text: data.join(' '),
              ));
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
