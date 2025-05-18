import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class SelectionController extends GetxController {
  // Use RxList and RxBool for reactive state management
  final RxList<MimeMessage> _selectedMessages = <MimeMessage>[].obs;
  final RxBool _isSelecting = false.obs;

  // Getter for isSelecting
  bool get isSelecting => _isSelecting.value;

  // Setter for isSelecting
  set isSelecting(bool value) {
    _isSelecting.value = value;
    if (!value) {
      _selectedMessages.clear();
    }
  }

  // Original API: selected getter
  RxList<MimeMessage> get selected => _selectedMessages;

  // Original API: toggle method
  void toggle(MimeMessage message) {
    if (!isSelecting) {
      isSelecting = true;
    }

    if (_selectedMessages.contains(message)) {
      _selectedMessages.remove(message);
      if (_selectedMessages.isEmpty) {
        isSelecting = false;
      }
    } else {
      _selectedMessages.add(message);
    }
  }

  // Original API: clear method
  void clear() {
    _selectedMessages.clear();
    isSelecting = false;
  }

  // New API: isSelected method
  bool isSelected(MimeMessage message) {
    return _selectedMessages.contains(message);
  }

  // New API: selectAll method
  void selectAll(List<MimeMessage> messages) {
    isSelecting = true;
    _selectedMessages.clear();
    _selectedMessages.addAll(messages);
  }

  // New API: selectedCount getter
  int get selectedCount => _selectedMessages.length;
}
