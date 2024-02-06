import 'package:get/get.dart';
import 'package:wahda_bank/views/view/models/user_model.dart';

class InboxController extends GetxController {
  static InboxController get instanse => Get.find();
  List<Users> users = allUsers.obs;
}

enum Actions { share, delete, archieve }
