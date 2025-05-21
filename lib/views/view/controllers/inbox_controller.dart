import 'dart:async';
import 'package:collection/collection.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/email_fetch_controller.dart';
import 'package:wahda_bank/app/controllers/email_storage_controller.dart';
import 'package:wahda_bank/app/controllers/email_ui_state_controller.dart';
import 'package:wahda_bank/app/controllers/mailbox_list_controller.dart';
import 'package:wahda_bank/models/sqlite_mailbox_storage.dart';
import 'package:wahda_bank/services/mail_service.dart';

/// Enhanced inbox controller with improved state management and caching
///
/// This controller manages the inbox view state, email filtering, and search functionality
class InboxController extends GetxController {
  static InboxController get instance => Get.find();

  // Dependencies
  final EmailFetchController fetchController = Get.find<EmailFetchController>();
  final EmailStorageController storageController = Get.find<EmailStorageController>();
  final EmailUiStateController uiStateController = Get.find<EmailUiStateController>();
  final MailboxListController mailboxController = Get.find<MailboxListController>();
  final MailService mailService = MailService.instance;

  // Reactive state
  final RxList<MimeMessage> _filteredEmails = <MimeMessage>[].obs;
  final RxBool _isSearchActive = false.obs;
  final RxString _searchQuery = ''.obs;
  final RxBool _isFilterActive = false.obs;
  final Rx<EmailFilter> _currentFilter = EmailFilter().obs;

  // Getters
  List<MimeMessage> get filteredEmails => _filteredEmails;
  bool get isSearchActive => _isSearchActive.value;
  String get searchQuery => _searchQuery.value;
  bool get isFilterActive => _isFilterActive.value;
  EmailFilter get currentFilter => _currentFilter.value;

  // Computed property for grouped emails
  Map<DateTime, List<MimeMessage>> get mailGroups => groupBy<MimeMessage, DateTime>(
    _filteredEmails,
        (item) => DateTime(
      item.decodeDate()?.year ?? DateTime.now().year,
      item.decodeDate()?.month ?? DateTime.now().month,
      item.decodeDate()?.day ?? DateTime.now().day,
    ),
  );

  // Stream subscriptions
  StreamSubscription<List<MimeMessage>>? _inboxStreamSubscription;

  @override
  void onInit() {
    super.onInit();

    // Initialize inbox
    _initializeInbox();

    // Listen for UI state changes

    ever(uiStateController.currentFilter, (_) => _applyFilters());

    // Listen for connection state changes
    ever(uiStateController.isConnected, (connected) {
      if (connected) {
        _refreshInbox();
      }
    });
  }

  /// Initialize inbox and subscribe to updates
  Future<void> _initializeInbox() async {
    try {
      // Ensure mailbox is selected
      if (mailboxController.mailBoxInbox == null) {
        await mailboxController.loadMailBoxes();
      }

      // Initialize storage for inbox
      if (mailboxController.mailBoxInbox != null) {
        storageController.initializeMailboxStorage(mailboxController.mailBoxInbox!);

        // Subscribe to inbox updates
        _subscribeToInboxUpdates();
      }
    } catch (e) {
      debugPrint('Error initializing inbox: $e');
    }
  }

  /// Subscribe to inbox updates
  void _subscribeToInboxUpdates() {
    // Cancel existing subscription
    _inboxStreamSubscription?.cancel();

    // Subscribe to inbox stream
    if (mailboxController.mailBoxInbox != null) {
      final mailboxStorage = storageController.mailboxStorage[mailboxController.mailBoxInbox!];

      if (mailboxStorage != null) {
        _inboxStreamSubscription = mailboxStorage.messageStream.listen((messages) {
          // Update filtered emails
          _applyFilters(messages);
        });
      }
    }
  }

  /// Refresh inbox
  Future<void> _refreshInbox() async {
    if (mailboxController.mailBoxInbox != null) {
      await fetchController.fetchNewEmails(mailboxController.mailBoxInbox!);
    }
  }

  /// Apply filters to emails
  void _applyFilters([List<MimeMessage>? messages]) {
    // Get messages from parameter or from storage
    final emails = messages ?? _getStoredEmails();

    // If no filter is active, use all emails
    if (!uiStateController.isFilterActive && _searchQuery.isEmpty) {
      _filteredEmails.assignAll(emails);
      return;
    }

    // Apply filters
    var filtered = emails;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.value.toLowerCase();
      filtered = filtered.where((email) {
        final subject = email.decodeSubject()?.toLowerCase() ?? '';
        final sender = email.from?.first.personalName?.toLowerCase() ?? '';
        final senderEmail = email.from?.first.email.toLowerCase() ?? '';
        final body = email.decodeTextPlainPart()?.toLowerCase() ?? '';

        return subject.contains(query) ||
            sender.contains(query) ||
            senderEmail.contains(query) ||
            body.contains(query);
      }).toList();
    }

    // Apply UI filters
    if (uiStateController.isFilterActive) {
      final filter = uiStateController.currentFilter.value;

      if (filter.onlyUnread) {
        filtered = filtered.where((email) => !email.isSeen).toList();
      }

      if (filter.onlyFlagged) {
        filtered = filtered.where((email) => email.isFlagged).toList();
      }

      if (filter.onlyWithAttachments) {
        filtered = filtered.where((email) => email.hasAttachments()).toList();
      }

      if (filter.fromDate != null) {
        filtered = filtered.where((email) {
          final date = email.decodeDate();
          return date != null && date.isAfter(filter.fromDate!);
        }).toList();
      }

      if (filter.toDate != null) {
        filtered = filtered.where((email) {
          final date = email.decodeDate();
          return date != null && date.isBefore(filter.toDate!);
        }).toList();
      }

      if (filter.searchTerm.isNotEmpty) {
        final term = filter.searchTerm.toLowerCase();
        filtered = filtered.where((email) {
          final subject = email.decodeSubject()?.toLowerCase() ?? '';
          final sender = email.from?.first.personalName?.toLowerCase() ?? '';
          final senderEmail = email.from?.first.email.toLowerCase() ?? '';

          return subject.contains(term) ||
              sender.contains(term) ||
              senderEmail.contains(term);
        }).toList();
      }
    }

    // Sort by date (newest first)
    filtered.sort((a, b) {
      final dateA = a.decodeDate() ?? DateTime.now();
      final dateB = b.decodeDate() ?? DateTime.now();
      return dateB.compareTo(dateA);
    });

    // Update filtered emails
    _filteredEmails.assignAll(filtered);
  }

  /// Get stored emails
  List<MimeMessage> _getStoredEmails() {
    if (mailboxController.mailBoxInbox == null) {
      return [];
    }

    return fetchController.emails[mailboxController.mailBoxInbox!] ?? [];
  }

  /// Set search query
  void setSearchQuery(String query) {
    _searchQuery.value = query;
    _isSearchActive.value = query.isNotEmpty;
    _applyFilters();
  }

  /// Clear search
  void clearSearch() {
    _searchQuery.value = '';
    _isSearchActive.value = false;
    _applyFilters();
  }

  /// Set filter
  void setFilter(EmailFilter filter) {
    _currentFilter.value = filter;
    _isFilterActive.value = !filter.isEmpty;
    _applyFilters();
  }

  /// Clear filter
  void clearFilter() {
    _currentFilter.value = EmailFilter();
    _isFilterActive.value = false;
    _applyFilters();
  }

  /// Load more emails
  Future<void> loadMoreEmails() async {
    if (mailboxController.mailBoxInbox != null) {
      await fetchController.loadMoreEmails(mailboxController.mailBoxInbox!);
    }
  }

  /// Refresh emails
  Future<void> refreshEmails() async {
    if (mailboxController.mailBoxInbox != null) {
      await fetchController.fetchNewEmails(mailboxController.mailBoxInbox!);
    }
  }

  @override
  void onClose() {
    _inboxStreamSubscription?.cancel();
    super.onClose();
  }
}

/// Email filter model
class EmailFilter {
  bool onlyUnread;
  bool onlyFlagged;
  bool onlyWithAttachments;
  DateTime? fromDate;
  DateTime? toDate;
  String searchTerm;

  EmailFilter({
    this.onlyUnread = false,
    this.onlyFlagged = false,
    this.onlyWithAttachments = false,
    this.fromDate,
    this.toDate,
    this.searchTerm = '',
  });

  bool get isEmpty =>
      !onlyUnread &&
          !onlyFlagged &&
          !onlyWithAttachments &&
          fromDate == null &&
          toDate == null &&
          searchTerm.isEmpty;
}
