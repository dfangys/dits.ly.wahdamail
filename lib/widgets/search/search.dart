import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/utills/constants/colors.dart';
import 'package:wahda_bank/views/view/showmessage/show_message.dart';
import 'package:wahda_bank/views/view/showmessage/show_message_pager.dart';
import 'package:wahda_bank/widgets/mail_tile.dart';
import '../empty_box.dart';
import 'controllers/mail_search_controller.dart';
import 'package:wahda_bank/shared/di/injection.dart';
import 'package:wahda_bank/features/search/presentation/search_view_model.dart';

class SearchView extends StatelessWidget {
  SearchView({super.key});
  final controller = Get.put(MailSearchController());
  final mailboxController = Get.find<MailBoxController>();
  // P12.2: bind UI to the ViewModel state
  final SearchViewModel vm = Get.put<SearchViewModel>(getIt<SearchViewModel>());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: TextFormField(
          controller: controller.searchController,
          onChanged: (String txt) {},
          decoration: InputDecoration(
            fillColor: WColors.fieldbackground,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 10,
            ),
            hintText: "search".tr,
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(7),
              borderSide: BorderSide.none,
            ),
            suffixIconConstraints: const BoxConstraints(
              maxHeight: 18,
              minWidth: 40,
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 2,
                  height: 20,
                  color: Theme.of(context).dividerColor,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                ),
                GestureDetector(
                  onTap: () {
                    vm.runSearch(
                      controller,
                      requestId: 'search_${DateTime.now().millisecondsSinceEpoch}',
                    );
                  },
                  child: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: vm.obx(
        (state) => ListView.separated(
          controller: controller.scrollController,
          itemBuilder: (context, index) {
            return MailTile(
              onTap: () {
                try {
                  final MimeMessage message = vm.searchMessages[index];
                  final listRef =
                      mailboxController.emails[mailboxController.mailBoxInbox] ??
                      const <MimeMessage>[];
                  int initial = 0;
                  if (listRef.isNotEmpty) {
                    initial = listRef.indexWhere(
                      (m) =>
                          (message.uid != null && m.uid == message.uid) ||
                          (message.sequenceId != null &&
                              m.sequenceId == message.sequenceId),
                    );
                    if (initial < 0) initial = 0;
                  }
                  Get.to(
                    () => ShowMessagePager(
                      mailbox: mailboxController.mailBoxInbox,
                      initialMessage: message,
                    ),
                  );
                } catch (_) {
                  Get.to(
                    () => ShowMessage(
                      message: vm.searchMessages[index],
                      mailbox: mailboxController.mailBoxInbox,
                    ),
                  );
                }
              },
              message: vm.searchMessages[index],
              mailBox: mailboxController.mailBoxInbox,
            );
          },
          separatorBuilder: (context, index) {
            return const Divider();
          },
          itemCount: vm.searchMessages.length,
        ),
        onEmpty: TAnimationLoaderWidget(
          text: 'Whoops! Box is empty',
          animation: 'assets/lottie/empty.json',
          showAction: true,
          actionText: 'try_again'.tr,
          onActionPressed: () {
            vm.runSearch(
              controller,
              requestId: 'search_${DateTime.now().millisecondsSinceEpoch}',
            );
          },
        ),
        onLoading: const Center(child: CircularProgressIndicator()),
        onError: (error) =>
            error.toString().startsWith('serach:')
                ? TAnimationLoaderWidget(
                    text: error.toString().split('serach:')[1],
                    animation: 'assets/lottie/search.json',
                    showAction: true,
                    actionText: 'search'.tr,
                    onActionPressed: () {
                      vm.runSearch(
                        controller,
                        requestId: 'search_${DateTime.now().millisecondsSinceEpoch}',
                      );
                    },
                  )
                : TAnimationLoaderWidget(
                    text: error.toString(),
                    animation: 'assets/lottie/error.json',
                    showAction: true,
                    actionText: 'search'.tr,
                    onActionPressed: () {
                      vm.runSearch(
                        controller,
                        requestId: 'search_${DateTime.now().millisecondsSinceEpoch}',
                      );
                    },
                  ),
      ),
    );
  }
}
