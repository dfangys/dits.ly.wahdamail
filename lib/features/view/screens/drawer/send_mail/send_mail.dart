import 'package:flutter/material.dart';
import 'package:wahda_bank/widgets/w_listtile.dart';

class SendMailScreen extends StatelessWidget {
  const SendMailScreen({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search),
          )
        ],
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
                    icon: Icons.star_border_purple500_outlined,
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
