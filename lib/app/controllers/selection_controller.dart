import 'package:enough_mail/enough_mail.dart';
import 'package:get/get.dart';

class SelectionController extends GetxController {
  final _selected = <MimeMessage>{}.obs;
  final _isSelecting = false.obs;

  // Expose reactive selecting flag for UI that needs to show/hide checkboxes
  RxBool get selecting => _isSelecting;

  // Compute a stable selection id for a message to drive granular UI updates
  String selectionIdFor(MimeMessage message) {
    final id = message.uid ?? message.sequenceId ?? message.hashCode;
    return 'sel_$id';
  }

  List<MimeMessage> get selected => _selected.toList();
  bool get isSelecting => _isSelecting.value;
  int get selectedCount => _selected.length;

  void toggle(MimeMessage message) {
    final bool wasSelecting = _selected.isNotEmpty;

    if (_selected.contains(message)) {
      _selected.remove(message);
    } else {
      _selected.add(message);
    }
    _isSelecting.value = _selected.isNotEmpty;

    final bool nowSelecting = _selected.isNotEmpty;
    try {
      if (wasSelecting != nowSelecting) {
        // Selection mode toggled on/off: rebuild all tiles to show/hide checkboxes
        update();
      }
      // Always update the specific tile as well for immediate feedback
      update([selectionIdFor(message)]);
    } catch (_) {}
  }

  void selectAll(List<MimeMessage> messages) {
    _selected.clear();
    _selected.addAll(messages);
    _isSelecting.value = _selected.isNotEmpty;
    try {
      update();
    } catch (_) {}
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
    try {
      update();
    } catch (_) {}
  }

  void deselectAll() {
    final ids = _selected.map(selectionIdFor).toList();
    _selected.clear();
    _isSelecting.value = false;
    try {
      update(); // update selection mode dependent UI (checkbox visibility)
      if (ids.isNotEmpty) update(ids); // update tiles that were selected
    } catch (_) {}
  }

  void clear() {
    final ids = _selected.map(selectionIdFor).toList();
    _selected.clear();
    _isSelecting.value = false;
    try {
      update();
      if (ids.isNotEmpty) update(ids);
    } catch (_) {}
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
