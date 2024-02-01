import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:wahda_bank/widgets/w_listtile.dart';

class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        centerTitle: true,
        actions: const [Icon(CupertinoIcons.add)],
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
                    icon: CupertinoIcons.delete,
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
