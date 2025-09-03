import 'dart:math';
import 'package:collection/collection.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/view/models/user_model.dart';

class InboxController extends GetxController {
  static InboxController get instanse => Get.find();
  List<Users> users = allUsers.obs;

  List<AppMail> mails = List.generate(
    200,
    (index) => AppMail(
      from: "Abdul Salam",
      email: "abcd@gmail.com",
      sumjet: "Collaboration Update: 🌐 Exploring أفق جديدة in our Partnership",
      message: "Connecting Worlds: 🌍 Your Input في مستقبلنا Matters",
      createdAt: DateTime(
        2024,
        1,
        Random.secure().nextInt(7),
        Random.secure().nextInt(24),
        Random.secure().nextInt(60),
      ),
    ),
  );

  Map<DateTime, List<AppMail>> get mailGroups => groupBy<AppMail, DateTime>(
    mails.toList(),
    (item) =>
        DateTime(item.createdAt.year, item.createdAt.month, item.createdAt.day),
  );
}

enum Actions { share, delete, archieve }

class AppMail {
  final String from;
  final String email;
  final String sumjet;
  final String message;
  final DateTime createdAt;

  AppMail({
    required this.from,
    required this.email,
    required this.sumjet,
    required this.message,
    required this.createdAt,
  });

  factory AppMail.fromJson(Map<String, dynamic> json) => AppMail(
    from: json["from"],
    email: json["email"],
    sumjet: json["sumjet"],
    message: json["message"],
    createdAt: DateTime.parse(json["created_at"]),
  );

  Map<String, dynamic> toJson() => {
    "from": from,
    "email": email,
    "sumjet": sumjet,
    "message": message,
    "created_at": createdAt.toIso8601String(),
  };
}
