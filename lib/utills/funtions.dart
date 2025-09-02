import 'package:awesome_dialog/awesome_dialog.dart';
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

Future confirmDraft(BuildContext context) async {
  return await AwesomeDialog(
    context: context,
    body: Padding(
      padding: const EdgeInsets.all(10),
      child: Text("confirm_save_draft".tr, textAlign: TextAlign.center),
    ),
    autoDismiss: false,
    dialogType: DialogType.question,
    btnCancelText: "cancel".tr,
    btnOkText: "save_as_draft".tr,
    btnCancelOnPress: () {
      Navigator.pop(context, false);
    },
    btnOkOnPress: () {
      Navigator.pop(context, true);
    },
    onDismissCallback: (type) {},
  ).show();
  // return false;
  // bool? confirm = await showCupertinoDialog(
  //   context: context,
  //   builder: (context) => CupertinoAlertDialog(
  //     content: Padding(
  //       padding: const EdgeInsets.all(10),
  //       child: Text("confirm_save_draft".tr),
  //     ),
  //     actions: [
  //       Padding(
  //         padding: const EdgeInsets.all(5),
  //         child: Row(
  //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //           children: [
  //             Expanded(
  //               child: TextButton(
  //                 onPressed: () {
  //                   Navigator.pop(context, false);
  //                 },
  //                 child: Text("cancel".tr),
  //               ),
  //             ),
  //             Container(
  //               width: 1,
  //               height: 20,
  //               color: Colors.grey,
  //             ),
  //             Expanded(
  //               child: TextButton(
  //                 onPressed: () {
  //                   Navigator.pop(context, true);
  //                 },
  //                 child: Text(
  //                   "save_as_draft".tr,
  //                   textAlign: TextAlign.center,
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //       )
  //     ],
  //   ),
  // );
  // return confirm ?? false;
}

DateTime filterDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final thisWeek = today.subtract(Duration(days: today.weekday - 1));
  final lastWeek = thisWeek.subtract(const Duration(days: 7));
  final thisMonth = DateTime(today.year, today.month, 1);
  final lastMonth = thisMonth.subtract(const Duration(days: 1));
  final threeMonthsAgo = today.subtract(const Duration(days: 90));
  final sixMonthsAgo = today.subtract(const Duration(days: 180));
  final lastYear = DateTime(today.year - 1, today.month, today.day);
  final moreThanLastYear = DateTime(1);
  if (date.isAfter(today)) {
    return today;
  } else if (date.isAfter(yesterday)) {
    return yesterday;
  } else if (date.isAfter(thisWeek)) {
    return thisWeek;
  } else if (date.isAfter(lastWeek)) {
    return lastWeek;
  } else if (date.isAfter(thisMonth)) {
    return thisMonth;
  } else if (date.isAfter(lastMonth)) {
    return lastMonth;
  } else if (date.isAfter(threeMonthsAgo)) {
    return threeMonthsAgo;
  } else if (date.isAfter(sixMonthsAgo)) {
    return sixMonthsAgo;
  } else if (date.isAfter(lastYear)) {
    return lastYear;
  } else {
    return moreThanLastYear;
  }
}
