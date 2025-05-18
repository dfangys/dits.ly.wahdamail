import 'dart:async';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/utills/extensions/mail_search_result_extensions.dart';

class MailSearchController extends GetxController with StateMixin {
  final searchController = TextEditingController();
  final searchFocusNode = FocusNode();

  // Observable properties for reactive UI updates
  final RxBool isSearching = false.obs;
  final RxBool hasMoreResults = false.obs;
  final RxInt totalResults = 0.obs;
  final RxString searchQuery = ''.obs;

  // Debounce for search to improve performance
  final debounce = Debounce(milliseconds: 500);

  MailClient get client => MailService.instance.client;

  List<MimeMessage> searchMessages = [];

  ScrollController scrollController = ScrollController();
  MailSearchResult? searchResults;

  @override
  void onInit() {
    super.onInit();

    // Initialize with arguments if provided
    if (Get.arguments != null) {
      searchController.text = Get.arguments['terms'];
      searchQuery.value = Get.arguments['terms'];
    }

    // Set initial state
    change(
      null,
      status: RxStatus.error('serach:${'enter_search_text'.tr}'),
    );

    // Set up scroll listener for pagination
    scrollController.addListener(() {
      if (scrollController.position.pixels >=
          scrollController.position.maxScrollExtent - 200) {
        // Load more when approaching the end (200px before end)
        onMoreScroll();
      }
    });

    // Clear search when focus is lost
    searchFocusNode.addListener(() {
      if (!searchFocusNode.hasFocus) {
        // Don't clear immediately to allow for interactions with search results
        // searchController.clear();
      }
    });

    // Listen for text changes
    searchController.addListener(() {
      searchQuery.value = searchController.text;

      if (searchController.text.isEmpty && searchMessages.isNotEmpty) {
        change(
          null,
          status: RxStatus.error('serach:${'enter_search_text'.tr}'),
        );
      } else if (searchController.text.isNotEmpty) {
        // Use debounce to avoid excessive searches while typing
        debounce.run(() {
          onSearch();
        });
      }
    });
  }

  Future<void> onSearch() async {
    if (searchController.text.isEmpty) return;

    isSearching.value = true;
    change(null, status: RxStatus.loading());

    try {
      searchResults = await client.searchMessages(
        MailSearch(
          searchController.text,
          SearchQueryType.allTextHeaders,
          messageType: SearchMessageType.all,
        ),
      );

      searchMessages.clear();

      if (searchResults != null) {
        searchMessages = searchResults!.messages;
        hasMoreResults.value = searchResults!.hasMoreResults;
        totalResults.value = searchResults!.messagesFound ?? searchMessages.length;

        if (searchMessages.isEmpty) {
          change(null, status: RxStatus.empty());
        } else {
          change(searchMessages, status: RxStatus.success());
        }
      }
    } catch (e) {
      change(null, status: RxStatus.error('Error: ${e.toString()}'));
    } finally {
      isSearching.value = false;
    }
  }

  Future<void> onMoreScroll() async {
    if (searchResults == null) return;
    if (!searchResults!.hasMoreResults) return;
    if (isSearching.value) return; // Prevent multiple simultaneous requests

    isSearching.value = true;
    change(searchMessages, status: RxStatus.loadingMore());

    try {
      var messages = await client.searchMessagesNextPage(searchResults!);
      searchMessages.addAll(messages);
      hasMoreResults.value = searchResults!.hasMoreResults;
      change(searchMessages, status: RxStatus.success());
    } catch (e) {
      // Keep existing results but show error toast
      Get.snackbar(
        'Error',
        'Failed to load more results: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.9),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      change(searchMessages, status: RxStatus.success());
    } finally {
      isSearching.value = false;
    }
  }

  // Clear search and results
  void clearSearch() {
    searchController.clear();
    searchMessages.clear();
    searchResults = null;
    hasMoreResults.value = false;
    totalResults.value = 0;
    change(null, status: RxStatus.error('serach:${'enter_search_text'.tr}'));
  }

  // Filter search by date range
  Future<void> filterByDateRange(DateTime? start, DateTime? end) async {
    if (searchController.text.isEmpty) return;
    if (start == null && end == null) return;

    isSearching.value = true;
    change(null, status: RxStatus.loading());

    try {
      // Create date criteria
      String dateQuery = '';
      if (start != null) {
        dateQuery += 'SINCE ${_formatSearchDate(start)} ';
      }
      if (end != null) {
        dateQuery += 'BEFORE ${_formatSearchDate(end.add(const Duration(days: 1)))} ';
      }

      // Combine with text search
      searchResults = await client.searchMessages(
        MailSearch(
          '${searchController.text} $dateQuery',
          SearchQueryType.allTextHeaders,
          messageType: SearchMessageType.all,
        ),
      );

      searchMessages.clear();

      if (searchResults != null) {
        searchMessages = searchResults!.messages;
        hasMoreResults.value = searchResults!.hasMoreResults;
        totalResults.value = searchResults!.messagesFound ?? searchMessages.length;

        if (searchMessages.isEmpty) {
          change(null, status: RxStatus.empty());
        } else {
          change(searchMessages, status: RxStatus.success());
        }
      }
    } catch (e) {
      change(null, status: RxStatus.error('Error: ${e.toString()}'));
    } finally {
      isSearching.value = false;
    }
  }

  // Format date for IMAP search
  String _formatSearchDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day}-${months[date.month - 1]}-${date.year}';
  }

  @override
  void onClose() {
    debounce.cancel();
    searchController.dispose();
    searchFocusNode.dispose();
    scrollController.dispose();
    super.onClose();
  }
}

// Debounce utility class
class Debounce {
  final int milliseconds;
  Timer? _timer;

  Debounce({required this.milliseconds});

  void run(VoidCallback action) {
    if (_timer?.isActive ?? false) {
      _timer?.cancel();
    }
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }

  void cancel() {
    _timer?.cancel();
  }
}
