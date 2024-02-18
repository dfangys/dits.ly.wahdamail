import 'package:enough_mail/enough_mail.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../views/view/models/box_model.dart';

class MailCountController extends GetxController {
  GetStorage storage = GetStorage();
  RxMap<String, int> counts = <String, int>{}.obs;

  @override
  void onInit() {
    fetchMailBoxes();
    ever(counts, (data) async {
      for (var e in data.entries) {
        await storage.write(e.key, e.value);
      }
    });
    super.onInit();
  }

  Future fetchMailBoxes() async {
    List boxes = storage.read('boxes') ?? [];
    if (boxes.isNotEmpty) {
      List<Mailbox> bList = boxes
          .map((e) => BoxModel.fromJson(e as Map<String, dynamic>))
          .toList();
      for (var b in bList) {
        String key = "${b.name.toLowerCase()}_count";
        counts[key] = storage.read(key) ?? b.messagesUnseen;
      }
    }
  }
}
