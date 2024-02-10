import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/views/view/inbox/inbox.dart';
import 'package:wahda_bank/views/view/screens/home/widgets/appbar.dart';
import 'package:wahda_bank/widgets/drawer/drawer.dart';
import 'package:wahda_bank/widgets/search/search.dart';
import 'package:wahda_bank/widgets/w_listtile.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../models/hive_mime_storage.dart';

class HomeScreen extends GetView<MailBoxController> {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    // final name = HiveMailboxMimeStorage.getBoxName(MailService.instance.account,
    //     MailService.instance.selectedBox, 'envelopes');
    return Scaffold(
      backgroundColor: AppTheme.cardDesignColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: appBar(),
      ),
      drawer: const Drawer1(),

      body: Obx(
        () {
          if (controller.isBusy()) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          return ListView.separated(
            itemBuilder: (context, index) => ListTile(
              title: Text(controller.boxMails[index].from![0].email),
              subtitle: Text(controller.boxMails[index].decodeSubject() ?? ''),
              onTap: () => Get.to(
                () => InboxScreen(),
              ),
            ),
            itemCount: controller.boxMails.length,
            separatorBuilder: (context, index) => const Divider(),
          );
        },
      ),
      // body: WListTile(
      //   selected: false,
      //   onTap: () => Get.to(() => InboxScreen()),
      // ),
      // body: ListView.builder(
      //   itemCount: controller.mailGroups.length,
      //   itemBuilder: (BuildContext context, int index) {
      //     var item = controller.mailGroups.entries.elementAt(index);
      //     return Column(
      //       crossAxisAlignment: CrossAxisAlignment.start,
      //       children: [
      //         Padding(
      //           padding: const EdgeInsets.symmetric(horizontal: 20),
      //           child: Text(
      //             timeago.format(item.key),
      //             style: const TextStyle(fontSize: 16),
      //           ),
      //         ),
      //         ListView.separated(
      //           shrinkWrap: true,
      //           physics: const NeverScrollableScrollPhysics(),
      //           itemBuilder: (context, i) {
      //             var mail = item.value.elementAt(i);
      //             return Padding(
      //               padding: const EdgeInsets.symmetric(horizontal: 20),
      //               child: Row(
      //                 crossAxisAlignment: CrossAxisAlignment.start,
      //                 children: [
      //                   CircleAvatar(
      //                     child: Text(
      //                       mail.from[0],
      //                       style: const TextStyle(
      //                         color: Colors.white,
      //                       ),
      //                     ),
      //                   ),
      //                   const SizedBox(width: 10),
      //                   Expanded(
      //                     child: Column(
      //                       children: [
      //                         Row(
      //                           children: [
      //                             Expanded(
      //                               child: Text(
      //                                 mail.email,
      //                                 style: const TextStyle(
      //                                   fontWeight: FontWeight.bold,
      //                                   fontSize: 14,
      //                                 ),
      //                               ),
      //                             ),
      //                             Text(
      //                               DateFormat("E HH:mm a")
      //                                   .format(mail.createdAt),
      //                               style: const TextStyle(
      //                                 color: Colors.grey,
      //                                 fontSize: 12,
      //                               ),
      //                             ),
      //                           ],
      //                         ),
      //                         Text(
      //                           mail.sumjet,
      //                           style: const TextStyle(
      //                             fontWeight: FontWeight.bold,
      //                           ),
      //                           maxLines: 1,
      //                           overflow: TextOverflow.ellipsis,
      //                         ),
      //                       ],
      //                     ),
      //                   ),
      //                 ],
      //               ),
      //             );
      //           },
      //           separatorBuilder: (context, i) => const Divider(
      //             color: Colors.grey,
      //           ),
      //           itemCount: item.value.length,
      //         ),
      //       ],
      //     );
      //   },
      // ),
    );
  }
}

class WSearchBar extends StatelessWidget {
  const WSearchBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        SearchController().clear();
        Get.to(
          SearchView(),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(top: 2, left: 10, right: 10),
        height: 40,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey.shade300,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Text(
                'Search',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              Container(
                width: 1,
                height: 20,
                color: Colors.grey.shade400,
                margin: const EdgeInsets.symmetric(horizontal: 5),
              ),
              GestureDetector(
                onTap: () {},
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
    );
  }
}
