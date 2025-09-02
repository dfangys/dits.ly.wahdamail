import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/shared/ddd_ui_wiring.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';

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
    if (Get.arguments != null) {
      searchController.text = Get.arguments['terms'];
    }
    change(null, status: RxStatus.error('serach:${'enter_search_text'.tr}'));
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

    // Telemetry: search attempt with request id
    final _req = DddUiWiring.newRequestId();
    final _sw = Stopwatch()..start();
    try {
      Telemetry.event('search_attempt', props: {
        'request_id': _req,
        'op': 'search',
        'q_len': searchController.text.length,
        'lat_ms': 0,
      });
    } catch (_) {}

    // P12: UI wiring behind flags — invoke DDD search when enabled
    try {
      final handled = await DddUiWiring.maybeSearch(controller: this);
      if (handled) {
        try {
          Telemetry.event('search_success', props: {
            'request_id': _req,
            'op': 'search',
            'lat_ms': _sw.elapsedMilliseconds,
          });
        } catch (_) {}
        return;
      }
    } catch (e) {
      try {
        Telemetry.event('search_failure', props: {
          'request_id': _req,
          'op': 'search',
          'lat_ms': _sw.elapsedMilliseconds,
          'error_class': e.runtimeType.toString(),
        });
      } catch (_) {}
    }

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
      if (searchMessages.isEmpty) {
        change(null, status: RxStatus.empty());
      } else {
        change(searchMessages, status: RxStatus.success());
      }
    }
    try {
      Telemetry.event('search_success', props: {
        'request_id': _req,
        'op': 'search',
        'lat_ms': _sw.elapsedMilliseconds,
      });
    } catch (_) {}
  } catch (e) {
      try {
        Telemetry.event('search_failure', props: {
          'request_id': _req,
          'op': 'search',
          'lat_ms': _sw.elapsedMilliseconds,
          'error_class': e.runtimeType.toString(),
        });
      } catch (_) {}
      change(null, status: RxStatus.error(e.toString()));
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
