import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/views/view/showmessage/show_message.dart';
import 'package:wahda_bank/views/view/showmessage/show_message_pager.dart';
import 'package:wahda_bank/widgets/mail_tile.dart';
import 'controllers/mail_search_controller.dart';
import 'package:wahda_bank/shared/di/injection.dart';
import 'package:wahda_bank/features/search/presentation/search_view_model.dart';
import 'package:wahda_bank/design_system/components/app_scaffold.dart';
import 'package:wahda_bank/design_system/theme/tokens.dart';
import 'package:wahda_bank/design_system/components/empty_state.dart';
import 'package:wahda_bank/design_system/components/error_state.dart';

class SearchView extends StatelessWidget {
  SearchView({super.key});
  final controller = Get.put(MailSearchController());
  final mailboxController = Get.find<MailBoxController>();
  // P12.2: bind UI to the ViewModel state
  final SearchViewModel vm = Get.put<SearchViewModel>(getIt<SearchViewModel>());

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: AppScaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Semantics(
          textField: true,
          label: 'Search field',
          child: TextFormField(
            controller: controller.searchController,
            onChanged: (String txt) {},
            decoration: InputDecoration(
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(
              vertical: Tokens.space3,
              horizontal: Tokens.space4,
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
                // Clear button
                Semantics(
                  button: true,
                  label: 'Clear',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    child: IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        controller.searchController.clear();
                      },
                    ),
                  ),
                ),
                // Divider between clear and search
                Container(
                  width: 2,
                  height: 20,
                  color: Theme.of(context).dividerColor,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                ),
                // Submit/Search button
                Semantics(
                  button: true,
                  label: 'Search',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    child: IconButton(
                      tooltip: 'Search',
                      icon: const Icon(Icons.search, size: 20),
                      onPressed: () {
                        vm.runSearch(
                          controller,
                          requestId: 'search_${DateTime.now().millisecondsSinceEpoch}',
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
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
        onEmpty: EmptyState(
          title: 'Whoops! Box is empty',
          message: null,
          icon: Icons.inbox,
        ),
        onLoading: const Center(child: CircularProgressIndicator()),
        onError: (error) => ErrorState(
          title: 'Error',
          message: error?.toString(),
          icon: Icons.error_outline,
        ),
      ),
      ),
    );
  }
}
