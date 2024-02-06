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
      body: const Column(
        children: [
          Expanded(child: WListTile(selected: false)),
        ],
      ),
    );
  }
}
