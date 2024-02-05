import 'package:flutter/material.dart';
import 'package:wahda_bank/features/view/inbox/widgets/inbox_app_bar.dart';
import 'package:wahda_bank/features/view/inbox/widgets/inbox_bottom_navbar.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';
import 'package:wahda_bank/utills/constants/text_strings.dart';

// ignore: must_be_immutable
class InboxScreen extends StatelessWidget {
  InboxScreen({super.key});
  bool isLoading = false;
  bool indicator = false;
  bool showMsgInfo = false;
  final String message = 'hi';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: InbocAppBar(indicator: indicator)),
      bottomNavigationBar: const InboxBottomNavBar(),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              child: ListTile(
                onTap: () {},
                leading: CircleAvatar(
                  backgroundColor:
                      Colors.primaries[0 % Colors.primaries.length],
                  radius: 25.0,
                  child: const Text(
                    'Z',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                title: const Text(
                  'Zaeem Ali',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text(
                  'Wed 7:32 AM',
                  maxLines: 1,
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ),
            const SizedBox(height: WSizes.defaultSpace),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: const Column(
                children: [
                  Text(
                    "Aliquma fringla nisi non lectus feugiat molestie",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: WSizes.defaultSpace),
                  Text(
                    WText.policyText,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  SizedBox(height: WSizes.defaultSpace),
                  Text(
                    WText.policyText2,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
