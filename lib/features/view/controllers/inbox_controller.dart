import 'package:get/get.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:wahda_bank/features/view/models/user_model.dart';

class InboxController extends GetxController {
  static InboxController get instanse => Get.find();
  List<Users> users = allUsers.obs;
  HtmlEditorController controller = HtmlEditorController();
}

enum Actions { share, delete, archieve }
