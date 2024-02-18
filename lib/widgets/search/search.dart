import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/utills/constants/colors.dart';
import 'package:wahda_bank/views/view/showmessage/show_message.dart';
import 'package:wahda_bank/widgets/mail_tile.dart';
import '../empty_box.dart';
import 'controllers/mail_search_controller.dart';

class SearchView extends StatelessWidget {
  SearchView({super.key});
  final controller = Get.put(MailSearchController());
  final mailboxController = Get.find<MailBoxController>();

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
            contentPadding:
                const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
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
                  color: Colors.grey.shade400,
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                ),
                GestureDetector(
                  onTap: () {
                    controller.onSearch();
                  },
                  child: const Icon(
                    Icons.search,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: controller.obx(
        (state) => ListView.separated(
          controller: controller.scrollController,
          itemBuilder: (context, index) {
            return MailTile(
              onTap: () {
                Get.to(
                  () => ShowMessage(
                    message: controller.searchMessages[index],
                    mailbox: mailboxController.mailBoxInbox,
                  ),
                );
              },
              message: controller.searchMessages[index],
              mailBox: mailboxController.mailBoxInbox,
            );
          },
          separatorBuilder: (context, index) {
            return const Divider();
          },
          itemCount: controller.searchMessages.length,
        ),
        onEmpty: TAnimationLoaderWidget(
          text: 'Whoops! Box is empty',
          animation: 'assets/lottie/empty.json',
          showAction: true,
          actionText: 'try_again'.tr,
          onActionPressed: () {
            controller.onSearch();
          },
        ),
        onLoading: const Center(
          child: CircularProgressIndicator(),
        ),
        onError: (error) => error.toString().startsWith('serach:')
            ? TAnimationLoaderWidget(
                text: error.toString().split('serach:')[1],
                animation: 'assets/lottie/search.json',
                showAction: true,
                actionText: 'search'.tr,
                onActionPressed: () {
                  controller.onSearch();
                },
              )
            : TAnimationLoaderWidget(
                text: error.toString(),
                animation: 'assets/lottie/error.json',
                showAction: true,
                actionText: 'try_again'.tr,
                onActionPressed: () {},
              ),
      ),
    );
  }
}
