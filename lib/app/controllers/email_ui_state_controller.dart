import 'dart:async';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:logger/logger.dart';
import 'package:wahda_bank/views/box/mailbox_view.dart';

import 'email_fetch_controller.dart';
import 'mailbox_list_controller.dart';

enum ViewType { inbox, drafts, sent, trash, compose, settings }

/// Controller responsible for managing UI state related to emails
class EmailUiStateController extends GetxController {
  final Logger logger = Logger();

  final Rx<ViewType> currentView = ViewType.inbox.obs;
  /// Switches the “pane” (inbox, drafts, sent, etc.)
  void setCurrentView(ViewType view) {
    currentView.value = view;
    logger.d('UI State: Current view changed to $view');
  }
  // Loading states
  final RxBool isBusy = false.obs;
  final RxBool isBoxBusy = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool isRefreshing = false.obs;

  // Mailbox loading states - track by mailbox path
  final RxMap<String, bool> mailboxLoadingStates = <String, bool>{}.obs;

  // Selected mailbox and message
  final Rx<Mailbox?> selectedMailbox = Rx<Mailbox?>(null);
  final Rx<MimeMessage?> selectedMessage = Rx<MimeMessage?>(null);

  // Search state
  final RxString searchQuery = ''.obs;
  final RxBool isSearching = false.obs;
  final RxList<MimeMessage> searchResults = <MimeMessage>[].obs;

  // View state
  final RxBool isComposeVisible = false.obs;
  final RxBool isDetailVisible = false.obs;
  final RxBool isSplitView = false.obs;

  // Connection state
  final RxBool isConnected = true.obs;

  // Debounce timer for search
  Timer? _searchDebounceTimer;

  // Controllers
  EmailFetchController? _fetchController;
  MailboxListController? _mailboxListController;


  @override
  void onInit() {
    try {
      // Grab fetch-controller if already registered
      if (Get.isRegistered<EmailFetchController>()) {
        _fetchController = Get.find<EmailFetchController>();
        _setupFetchControllerListeners();
      }

      // Grab mailbox-list controller if registered
      if (Get.isRegistered<MailboxListController>()) {
        _mailboxListController = Get.find<MailboxListController>();
      }

      // Listen for changes in selected mailbox
      ever<Mailbox?>(selectedMailbox, (mailbox) {
        if (mailbox != null) {
          logger.d("UI State: Selected mailbox changed to ${mailbox.name}");
          _mailboxListController?.selectedMailbox = mailbox;
        }
      });

      // Listen for changes in selected message
      ever<MimeMessage?>(selectedMessage, (message) {
        if (message != null) {
          logger.d("UI State: Selected message changed to ${message.decodeSubject() ?? 'No subject'}");
          isDetailVisible(true);
        }
      });

      super.onInit();
    } catch (e) {
      logger.e("Error initializing EmailUiStateController: $e");
      super.onInit();
    }
  }

  /// Setup listeners for fetch controller
  void _setupFetchControllerListeners() {
    if (_fetchController == null) return;

    // Listen to fetch controller loading states
    ever(_fetchController!.isBusy, (bool value) => isBusy.value = value);
    ever(_fetchController!.isBoxBusy, (bool value) => isBoxBusy.value = value);
    ever(_fetchController!.isLoadingMore, (bool value) => isLoadingMore.value = value);
    ever(_fetchController!.isRefreshing, (bool value) => isRefreshing.value = value);

    logger.d("Set up fetch controller listeners");
  }
  /// Alias for backward‐compatible naming:
  void setCurrentMailbox(Mailbox mailbox) => setSelectedMailbox(mailbox);

  /// Clears the selected mailbox (and resets detail/search)
  void clearCurrentMailbox() {
    selectedMailbox.value = null;
    selectedMessage.value  = null;
    clearSearch();
    // if you want to also reset filter here, you can
    // clearFilter();
  }


  /// Set the selected mailbox
  void setSelectedMailbox(Mailbox mailbox) {
    selectedMailbox.value = mailbox;

    // Clear selected message when changing mailbox
    selectedMessage.value = null;

    // Update detail visibility
    isDetailVisible(false);

    // Clear search when changing mailbox
    clearSearch();

    logger.d("UI State: Set selected mailbox to ${mailbox.name}");
  }


  // 2) Filter state:
  final Rx<MessageFilter> currentFilter = MessageFilter().obs;
  bool get isFilterActive => !currentFilter.value.isEmpty;

  void setFilter(MessageFilter filter) {
    currentFilter.value = filter;
  }

  void clearFilter() {
    currentFilter.value = MessageFilter();
  }

  /// Set the selected message
  void setSelectedMessage(MimeMessage? message) {
    selectedMessage.value = message;

    // Update detail visibility
    if (message != null) {
      isDetailVisible(true);
    }

    logger.d("UI State: Set selected message to ${message?.decodeSubject() ?? 'null'}");
  }

  /// Set mailbox loading state
  void setMailboxLoading(Mailbox mailbox, bool isLoading) {
    mailboxLoadingStates[mailbox.encodedPath] = isLoading;
    logger.d("UI State: Set mailbox ${mailbox.name} loading state to $isLoading");
  }

  /// Get mailbox loading state
  bool isMailboxLoading(Mailbox mailbox) {
    return mailboxLoadingStates[mailbox.encodedPath] ?? false;
  }

  /// Set loading more state
  void setLoadingMore(bool isLoading) {
    isLoadingMore.value = isLoading;
    logger.d("UI State: Set loading more state to $isLoading");
  }

  /// Set refreshing state
  void setRefreshing(bool isRefreshing) {
    this.isRefreshing.value = isRefreshing;
    logger.d("UI State: Set refreshing state to $isRefreshing");
  }

  /// Set compose visibility
  void setComposeVisible(bool isVisible) {
    isComposeVisible.value = isVisible;
    logger.d("UI State: Set compose visibility to $isVisible");
  }

  /// Toggle split view
  void toggleSplitView() {
    isSplitView.value = !isSplitView.value;
    logger.d("UI State: Toggled split view to ${isSplitView.value}");
  }

  /// Set connection state
  void setConnectionState(bool isConnected) {
    this.isConnected.value = isConnected;
    logger.d("UI State: Set connection state to $isConnected");
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

    logger.d("UI State: Started search with query '$query'");
  }

  /// Clear search
  void clearSearch() {
    searchQuery.value = '';
    isSearching.value = false;
    searchResults.clear();
    _searchDebounceTimer?.cancel();

    logger.d("UI State: Cleared search");
  }

  /// Perform search on current mailbox with improved search logic
  void _performSearch() {
    if (searchQuery.value.isEmpty) {
      searchResults.clear();
      return;
    }

    if (selectedMailbox.value == null) return;

    final mailbox = selectedMailbox.value!;

    if (_fetchController != null) {
      final emails = _fetchController!.getEmailsForMailbox(mailbox);
      final query = searchQuery.value.toLowerCase();

      // Search in subject, from, to, and body preview fields
      final results = emails.where((message) {
        // Search in subject
        final subject = message.decodeSubject()?.toLowerCase() ?? '';
        if (subject.contains(query)) return true;

        // Search in from addresses
        if (message.from != null) {
          for (var from in message.from!) {
            if ((from.personalName?.toLowerCase() ?? '').contains(query) ||
                (from.email.toLowerCase()).contains(query)) {
              return true;
            }
          }
        }

        // Search in to addresses
        if (message.to != null) {
          for (var to in message.to!) {
            if ((to.personalName?.toLowerCase() ?? '').contains(query) ||
                (to.email.toLowerCase()).contains(query)) {
              return true;
            }
          }
        }

        // Search in cc addresses
        if (message.cc != null) {
          for (var cc in message.cc!) {
            if ((cc.personalName?.toLowerCase() ?? '').contains(query) ||
                (cc.email.toLowerCase()).contains(query)) {
              return true;
            }
          }
        }

        // Search in body preview if available
        final preview = message.decodeTextPlainPart()?.toLowerCase() ?? '';
        if (preview.contains(query)) return true;

        return false;
      }).toList();

      searchResults.value = results;
      logger.d("UI State: Search found ${results.length} results for query '$query'");
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

    logger.d("UI State: Showed loading dialog with message '$message'");
  }

  /// Hide loading indicator
  void hideLoading() {
    if (Get.isDialogOpen ?? false) {
      Get.back();
      logger.d("UI State: Hid loading dialog");
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

    logger.d("UI State: Showed error message '$message'");
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

    logger.d("UI State: Showed success message '$message'");
  }

  /// Show confirmation dialog
  Future<bool> showConfirmation(String title, String message) async {
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Confirm'),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    logger.d("UI State: Showed confirmation dialog with result ${result ?? false}");
    return result ?? false;
  }

  /// Refresh UI state from controllers
  void refreshState() {
    try {
      // Refresh from fetch controller
      if (_fetchController != null) {
        isBusy.value = _fetchController!.isBusy.value;
        isBoxBusy.value = _fetchController!.isBoxBusy.value;
        isLoadingMore.value = _fetchController!.isLoadingMore.value;
        isRefreshing.value = _fetchController!.isRefreshing.value;
      }

      // Refresh from mailbox list controller
      if (_mailboxListController != null && _mailboxListController!.selectedMailbox != null) {
        selectedMailbox.value = _mailboxListController!.selectedMailbox;
      }

      logger.d("UI State: Refreshed state from controllers");
    } catch (e) {
      logger.e("Error refreshing UI state: $e");
    }
  }

  @override
  void onClose() {
    _searchDebounceTimer?.cancel();
    super.onClose();
  }
}
