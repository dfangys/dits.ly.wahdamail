import 'dart:async';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';

import 'email_fetch_controller.dart';

/// Controller responsible for managing UI state related to emails
class EmailUIStateController extends GetxController {
  final Logger logger = Logger();

  // Loading states
  final RxBool isBusy = false.obs;
  final RxBool isBoxBusy = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool isRefreshing = false.obs;

  // Selected mailbox and message
  final Rx<Mailbox?> selectedMailbox = Rx<Mailbox?>(null);
  final Rx<MimeMessage?> selectedMessage = Rx<MimeMessage?>(null);

  // Search state
  final RxString searchQuery = ''.obs;
  final RxBool isSearching = false.obs;
  final RxList<MimeMessage> searchResults = <MimeMessage>[].obs;

  // Debounce timer for search
  Timer? _searchDebounceTimer;

  @override
  void onInit() {
    try {
      // Get other controllers if needed
      if (Get.isRegistered<EmailFetchController>()) {
        final fetchController = Get.find<EmailFetchController>();

        // Listen to fetch controller loading states
        ever(fetchController.isBusy, (bool value) => isBusy.value = value);
        ever(fetchController.isBoxBusy, (bool value) => isBoxBusy.value = value);
        ever(fetchController.isLoadingMore, (bool value) => isLoadingMore.value = value);
        ever(fetchController.isRefreshing, (bool value) => isRefreshing.value = value);
      }

      super.onInit();
    } catch (e) {
      logger.e(e);
    }
  }

  /// Set the selected mailbox
  void setSelectedMailbox(Mailbox mailbox) {
    selectedMailbox.value = mailbox;

    // Clear selected message when changing mailbox
    selectedMessage.value = null;

    // Clear search when changing mailbox
    clearSearch();
  }

  /// Set the selected message
  void setSelectedMessage(MimeMessage? message) {
    selectedMessage.value = message;
  }

  /// Start search with query
  void search(String query) {
    searchQuery.value = query;
    isSearching.value = true;

    // Cancel existing timer
    _searchDebounceTimer?.cancel();

    // Set new timer to debounce search
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch();
    });
  }

  /// Clear search
  void clearSearch() {
    searchQuery.value = '';
    isSearching.value = false;
    searchResults.clear();
    _searchDebounceTimer?.cancel();
  }

  /// Perform search on current mailbox
  void _performSearch() {
    if (searchQuery.value.isEmpty) {
      searchResults.clear();
      return;
    }

    if (selectedMailbox.value == null) return;

    final mailbox = selectedMailbox.value!;

    if (Get.isRegistered<EmailFetchController>()) {
      final fetchController = Get.find<EmailFetchController>();
      final emails = fetchController.getEmailsForMailbox(mailbox);
      final query = searchQuery.value.toLowerCase();

      // Search in subject, from, and to fields
      final results = emails.where((message) {
        final subject = message.decodeSubject()?.toLowerCase() ?? '';

        // Search in from addresses
        bool matchesFrom = false;
        if (message.from != null) {
          for (var from in message.from!) {
            if ((from.personalName?.toLowerCase() ?? '').contains(query) ||
                (from.email.toLowerCase()).contains(query)) {
              matchesFrom = true;
              break;
            }
          }
        }

        // Search in to addresses
        bool matchesTo = false;
        if (message.to != null) {
          for (var to in message.to!) {
            if ((to.personalName?.toLowerCase() ?? '').contains(query) ||
                (to.email.toLowerCase()).contains(query)) {
              matchesTo = true;
              break;
            }
          }
        }

        return subject.contains(query) || matchesFrom || matchesTo;
      }).toList();

      searchResults.value = results;
    }
  }

  /// Show loading indicator
  void showLoading(String message) {
    Get.dialog(
      Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  /// Hide loading indicator
  void hideLoading() {
    if (Get.isDialogOpen ?? false) {
      Get.back();
    }
  }

  /// Show error message
  void showError(String message) {
    Get.showSnackbar(
      GetSnackBar(
        message: message,
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show success message
  void showSuccess(String message) {
    Get.showSnackbar(
      GetSnackBar(
        message: message,
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void onClose() {
    _searchDebounceTimer?.cancel();
    super.onClose();
  }
}
