import 'package:intl/intl.dart';

String formatDate(DateTime? dateTime) {
  String formatedDate;
  dateTime = dateTime ?? DateTime.now();
  if (DateTime.now().difference(dateTime).inDays > 7) {
    formatedDate = DateFormat('dd/MM/yyyy').format(dateTime);
  } else {
    formatedDate = DateFormat('EEE, h:mm a').format(dateTime);
  }
  return formatedDate;
}
