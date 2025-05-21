import 'package:enough_mail/enough_mail.dart';
import 'package:get/get.dart';

class SelectionController extends GetxController {
  final RxSet<MimeMessage> _selected = <MimeMessage>{}.obs;
  final RxBool _isSelecting = false.obs;

  List<MimeMessage> get selectedItems => _selected.toList();
  bool get isSelecting => _selected.isNotEmpty;

  void toggleSelection(MimeMessage message) {
    if (_selected.contains(message)) {
      _selected.remove(message);
    } else {
      _selected.add(message);
    }
    _isSelecting.value = _selected.isNotEmpty;
  }

  void clearSelection() {
    _selected.clear();
    _isSelecting.value = false;
  }

  // Alias methods for backward compatibility
  void toggle(MimeMessage message) => toggleSelection(message);
  void clear() => clearSelection();
  List<MimeMessage> get selected => selectedItems;

  // Check if a message is selected
  bool isSelected(MimeMessage message) {
    return _selected.contains(message);
  }

  // Select multiple messages
  void selectMultiple(List<MimeMessage> messages) {
    _selected.addAll(messages);
    _isSelecting.value = _selected.isNotEmpty;
  }

  // Deselect multiple messages
  void deselectMultiple(List<MimeMessage> messages) {
    _selected.removeAll(messages);
    _isSelecting.value = _selected.isNotEmpty;
  }

  // Toggle selection for multiple messages
  void toggleMultiple(List<MimeMessage> messages) {
    for (final message in messages) {
      toggleSelection(message);
    }
  }

  // Select all messages
  void selectAll(List<MimeMessage> allMessages) {
    _selected.addAll(allMessages);
    _isSelecting.value = _selected.isNotEmpty;
  }
}
