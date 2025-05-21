import 'package:enough_mail/enough_mail.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../views/view/models/box_model.dart';

class MailCountController extends GetxController {
  final GetStorage storage = GetStorage();
  final RxMap<String, int> counts = <String, int>{}.obs;

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

  Future<void> fetchMailBoxes() async {
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

  void setCount(String key, int value) {
    counts[key] = value;
    counts.refresh();
    storage.write(key, value);
  }

  // Get count for a specific mailbox
  int getCount(String mailboxName) {
    String key = "${mailboxName.toLowerCase()}_count";
    return counts[key] ?? 0;
  }

  // Update count for a specific mailbox
  void updateCount(String mailboxName, int value) {
    String key = "${mailboxName.toLowerCase()}_count";
    setCount(key, value);
  }

  // Increment count for a specific mailbox
  void incrementCount(String mailboxName, [int increment = 1]) {
    String key = "${mailboxName.toLowerCase()}_count";
    int currentCount = counts[key] ?? 0;
    setCount(key, currentCount + increment);
  }

  Future<void> updateUnreadCount(Mailbox mailbox) async {
    try {
      final name = mailbox.name.toLowerCase();
      final count = mailbox.messagesUnseen ?? 0;
      updateCount(name, count);
    } catch (e) {
      print('Error updating unread count for ${mailbox.name}: $e');
    }
  }

  // Decrement count for a specific mailbox
  void decrementCount(String mailboxName, [int decrement = 1]) {
    String key = "${mailboxName.toLowerCase()}_count";
    int currentCount = counts[key] ?? 0;
    setCount(key, currentCount > decrement ? currentCount - decrement : 0);
  }

  // Reset count for a specific mailbox
  void resetCount(String mailboxName) {
    String key = "${mailboxName.toLowerCase()}_count";
    setCount(key, 0);
  }
}
