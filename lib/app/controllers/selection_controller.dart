import 'package:enough_mail/enough_mail.dart';
import 'package:get/get.dart';

class SelectionController extends GetxController {
  final _selected = <MimeMessage>{}.obs;
  final _isSelecting = false.obs;

  List<MimeMessage> get selected => _selected.toList();
  bool get isSelecting => _isSelecting.value;

  void toggle(MimeMessage message) {
    if (_selected.contains(message)) {
      _selected.remove(message);
    } else {
      _selected.add(message);
    }
    _isSelecting.value = _selected.isNotEmpty;
  }

  void clear() {
    _selected.clear();
    _isSelecting.value = false;
  }
}
