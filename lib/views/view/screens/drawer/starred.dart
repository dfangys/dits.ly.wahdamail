import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/widgets/w_listtile.dart';

class StarredScreen extends StatelessWidget {
  const StarredScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'starred'.tr,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
        actions: const [Icon(Icons.search)],
      ),
      body: const Column(
        children: [
          Expanded(
              child: WListTile(
            selected: false,
            icon: Icons.star_rate,
            iconColor: Colors.yellow,
          )),
        ],
      ),
    );
  }
}
