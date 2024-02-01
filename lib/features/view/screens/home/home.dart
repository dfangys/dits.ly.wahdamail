import 'package:flutter/material.dart';
import 'package:wahda_bank/features/view/screens/home/widgets/appbar.dart';
import 'package:wahda_bank/widgets/drawer/drawer.dart';
import 'package:wahda_bank/widgets/w_listtile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
          preferredSize: const Size.fromHeight(50), child: appBar()),
      drawer: const Drawer1(),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
                padding: const EdgeInsets.only(top: 20),
                physics: const BouncingScrollPhysics(),
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  return WListTile(
                    selected: false,
                    onTap: () {},
                  );
                },
                separatorBuilder: (_, __) => Divider(
                      height: 2,
                      color: Colors.grey.shade300,
                    ),
                itemCount: 10),
          ),
        ],
      ),
    );
  }
}
