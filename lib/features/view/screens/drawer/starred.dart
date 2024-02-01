import 'package:flutter/material.dart';
import 'package:wahda_bank/widgets/w_listtile.dart';

class StarredScreen extends StatelessWidget {
  const StarredScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Starred'),
        centerTitle: true,
        actions: const [Icon(Icons.search)],
      ),
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
                    icon: Icons.star,
                    iconColor: Colors.green,
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
