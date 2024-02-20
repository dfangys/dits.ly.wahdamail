import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

String mailTileTimeFormat(DateTime? dateTime) {
  String formatedDate;
  dateTime = dateTime ?? DateTime.now();
  if (DateTime.now().difference(dateTime).inDays > 7) {
    formatedDate = DateFormat('dd/MM/yyyy').format(dateTime);
  } else {
    formatedDate = DateFormat('EEE, h:mm a').format(dateTime);
  }
  return formatedDate;
}

Future<bool> confirmDraft(BuildContext context) async {
  bool? confirm = await showDialog(
    context: context,
    builder: (context) => CupertinoAlertDialog(
      title: Padding(
        padding: const EdgeInsets.all(10),
        child: Text("confirm_save_draft".tr),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context, false);
                  },
                  child: Text("cancel".tr),
                ),
              ),
              Container(
                width: 1,
                height: 20,
                color: Colors.grey,
              ),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  child: Text(
                    "save_as_draft".tr,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        )
      ],
    ),
  );
  return confirm ?? false;
}
