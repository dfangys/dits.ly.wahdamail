import 'package:enough_mail/enough_mail.dart';
import 'package:get/get.dart';

class SelectionController extends GetxController {
  final _selected = <MimeMessage>{}.obs;
  final _isSelecting = false.obs;

  List<MimeMessage> get selected => _selected.toList();
  bool get isSelecting => selected.isNotEmpty;
  int get selectedCount => _selected.length;

  void toggle(MimeMessage message) {
    if (_selected.contains(message)) {
      _selected.remove(message);
    } else {
      _selected.add(message);
    }
    _isSelecting.value = _selected.isNotEmpty;
  }

  void selectAll(List<MimeMessage> messages) {
    _selected.clear();
    _selected.addAll(messages);
    _isSelecting.value = _selected.isNotEmpty;
  }

  void selectRange(List<MimeMessage> messages, int startIndex, int endIndex) {
    final start = startIndex < endIndex ? startIndex : endIndex;
    final end = startIndex < endIndex ? endIndex : startIndex;
    
    for (int i = start; i <= end && i < messages.length; i++) {
      if (!_selected.contains(messages[i])) {
        _selected.add(messages[i]);
      }
    }
    _isSelecting.value = _selected.isNotEmpty;
  }

  void deselectAll() {
    _selected.clear();
    _isSelecting.value = false;
  }

  void clear() {
    _selected.clear();
    _isSelecting.value = false;
  }

  bool isSelected(MimeMessage message) {
    return _selected.contains(message);
  }

  // Get selected messages by type
  List<MimeMessage> get selectedUnreadMessages {
    return _selected.where((msg) => !msg.isSeen).toList();
  }

  List<MimeMessage> get selectedReadMessages {
    return _selected.where((msg) => msg.isSeen).toList();
  }

  List<MimeMessage> get selectedFlaggedMessages {
    return _selected.where((msg) => msg.isFlagged).toList();
  }
}
