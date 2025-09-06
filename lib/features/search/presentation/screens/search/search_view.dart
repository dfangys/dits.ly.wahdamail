import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/app/api/mailbox_controller_api.dart';
import 'package:wahda_bank/features/messaging/presentation/screens/message_detail/show_message.dart';
import 'package:wahda_bank/features/messaging/presentation/screens/message_detail/show_message_pager.dart';
import 'package:wahda_bank/widgets/mail_tile.dart';
import 'package:wahda_bank/features/search/presentation/api/mail_search_controller_api.dart';
import 'package:wahda_bank/shared/di/injection.dart';
import 'package:wahda_bank/features/search/presentation/search_view_model.dart';
import 'package:wahda_bank/design_system/components/app_scaffold.dart';
import 'package:wahda_bank/design_system/theme/tokens.dart';
import 'package:wahda_bank/design_system/components/empty_state.dart';
import 'package:wahda_bank/design_system/components/error_state.dart';
import 'package:wahda_bank/design_system/components/query_chip.dart';
import 'package:wahda_bank/observability/perf/list_perf_sampler.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  late final MailSearchController controller;
  late final MailBoxController mailboxController;
  late final SearchViewModel vm;
  ListPerfSampler? _perf;

  @override
  void initState() {
    super.initState();
    controller = Get.put(MailSearchController());
    mailboxController = Get.find<MailBoxController>();
    vm = Get.put<SearchViewModel>(getIt<SearchViewModel>());
    // Start perf sampler after first frame to ensure controller wired
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _perf = ListPerfSampler(
        opName: 'search_list_scroll',
        scrollController: controller.scrollController,
      )..start();
    });
  }

  @override
  void dispose() {
    try {
      _perf?.stop();
    } catch (_) {}
    super.dispose();
  }

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
              onChanged: (String txt) {
                // UI-only: rebuild to reflect query chip row; no behavior/logics changed
                setState(() {});
              },
              decoration: InputDecoration(
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
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
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
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
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        child: IconButton(
                          tooltip: 'Search',
                          icon: const Icon(Icons.search, size: 20),
                          onPressed: () {
                            vm.runSearch(
                              controller,
                              requestId:
                                  'search_${DateTime.now().millisecondsSinceEpoch}',
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
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Query chip row (static UI only)
            if (controller.searchController.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Tokens.space5,
                  Tokens.space4,
                  Tokens.space5,
                  Tokens.space3,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      QueryChip(label: controller.searchController.text.trim()),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: vm.obx(
                (state) => ListView.separated(
                  controller: controller.scrollController,
                  cacheExtent: 360.0, // ~3 rows
                  padding: const EdgeInsets.symmetric(
                    horizontal: Tokens.space5,
                  ),
                  itemBuilder: (context, index) {
                    return MailTile(
                      onTap: () {
                        try {
                          final MimeMessage message = vm.searchMessages[index];
                          final listRef =
                              mailboxController.emails[mailboxController
                                  .mailBoxInbox] ??
                              const <MimeMessage>[];
                          int initial = 0;
                          if (listRef.isNotEmpty) {
                            initial = listRef.indexWhere(
                              (m) =>
                                  (message.uid != null &&
                                      m.uid == message.uid) ||
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
                    return const Divider(height: 1);
                  },
                  itemCount: vm.searchMessages.length,
                ),
                onEmpty: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Tokens.space5,
                    vertical: Tokens.space6,
                  ),
                  child: EmptyState(
                    title: 'Whoops! Box is empty',
                    message: null,
                    icon: Icons.inbox,
                  ),
                ),
                onLoading: const Center(child: CircularProgressIndicator()),
                onError:
                    (error) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Tokens.space5,
                        vertical: Tokens.space6,
                      ),
                      child: ErrorState(
                        title: 'Error',
                        message: error?.toString(),
                        icon: Icons.error_outline,
                      ),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
