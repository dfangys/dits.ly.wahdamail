import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/services/mail_service.dart';

class MailSearchController extends GetxController with StateMixin {
  final searchController = TextEditingController();
  final searchFocusNode = FocusNode();

  MailClient client = MailService.instance.client;

  List<MimeMessage> searchMessages = [];

  ScrollController scrollController = ScrollController();
  MailSearchResult? searchResults;

  @override
  void onInit() {
    super.onInit();
    change(
      null,
      status: RxStatus.error('serach:${'enter_search_text'.tr}'),
    );
    scrollController.addListener(() {
      if (scrollController.position.pixels ==
          scrollController.position.maxScrollExtent) {
        onMoreScroll();
      }
    });
    searchFocusNode.addListener(() {
      if (!searchFocusNode.hasFocus) {
        searchController.clear();
      }
    });

    searchController.addListener(() {
      if (searchController.text.isEmpty && searchMessages.isNotEmpty) {
        change(
          null,
          status: RxStatus.error('serach:${'enter_search_text'.tr}'),
        );
      }
    });
  }

  Future onSearch() async {
    if (searchController.text.isEmpty) return;
    change(null, status: RxStatus.loading());
    searchResults = await client.searchMessages(
      MailSearch(
        searchController.text,
        SearchQueryType.allTextHeaders,
      ),
    );
    searchMessages.clear();
    if (searchResults != null) {
      searchMessages = searchResults!.messages;
      if (searchMessages.isEmpty) {
        change(null, status: RxStatus.empty());
      } else {
        change(searchMessages, status: RxStatus.success());
      }
    }
  }

  Future onMoreScroll() async {
    if (searchResults == null) return;
    if (!searchResults!.hasMoreResults) return;
    change(null, status: RxStatus.loadingMore());
    var messages = await client.searchMessagesNextPage(searchResults!);
    searchMessages.addAll(messages);
  }

  @override
  void onClose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.onClose();
  }
}
