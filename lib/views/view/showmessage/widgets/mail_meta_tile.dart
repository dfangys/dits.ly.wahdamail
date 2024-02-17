import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class MailMetaTile extends StatefulWidget {
  const MailMetaTile({super.key, required this.message});
  final MimeMessage message;
  @override
  State<MailMetaTile> createState() => _MailMetaTileState();
}

class _MailMetaTileState extends State<MailMetaTile> {
  bool isShow = false;
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: TextButton(
        onPressed: () {
          setState(() {
            isShow = !isShow;
          });
        },
        child: const Text('Show'),
      ),
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
                widget.message.from != null
                    ? widget.message.from!.map((e) => e.email).toList()
                    : [],
              ),
              buildMailInfo(
                "To",
                widget.message.to != null
                    ? widget.message.to!.map((e) => e.email).toList()
                    : [],
              ),
              buildMailInfo(
                "Cc",
                widget.message.cc != null
                    ? widget.message.cc!.map((e) => e.email).toList()
                    : [],
              ),
              buildMailInfo(
                "Bcc",
                widget.message.bcc != null
                    ? widget.message.bcc!.map((e) => e.email).toList()
                    : [],
              ),
              buildMailInfo(
                "Time",
                [
                  DateFormat().format(
                    widget.message.decodeDate() ?? DateTime.now(),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
      crossFadeState:
          isShow ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 500),
      firstCurve: Curves.bounceOut,
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
