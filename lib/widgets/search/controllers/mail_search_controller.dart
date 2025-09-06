import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/shared/logging/telemetry.dart';
import 'package:wahda_bank/features/search/presentation/search_view_model.dart';
import 'package:wahda_bank/shared/di/injection.dart';
import 'dart:math' as math;

@Deprecated('Replaced by ViewModels. Will be removed in P12.4')
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
    final _req =
        'req-${DateTime.now().microsecondsSinceEpoch}-${math.Random().nextInt(0x7fffffff)}';
    try {
      Telemetry.event(
        'search_attempt',
        props: {
          'request_id': _req,
          'op': 'search',
          'q_len': searchController.text.length,
          'lat_ms': 0,
        },
      );
    } catch (_) {}

    // Delegate orchestration to presentation ViewModel (handles DDD/legacy + operation telemetry)
    final vm = getIt<SearchViewModel>();
    await vm.runSearchText(searchController.text, requestId: _req);
    return;
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
