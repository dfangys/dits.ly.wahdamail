import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class WSliverAppBar extends StatelessWidget {
  const WSliverAppBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.grey.shade300,
      pinned: true,
      expandedHeight: 100,
      elevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: const Text(
          'Inbox',
          style: TextStyle(color: Colors.black),
        ),
        background: Container(
          width: double.infinity,
          color: Colors.grey.shade300,
        ),
      ),
      title: Row(
        children: [
          const Icon(
            CupertinoIcons.back,
            color: Colors.green,
          ),
          Text(
            'Accounts',
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .apply(color: Colors.green),
          )
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {},
          child: const Text(
            'Edit',
            style: TextStyle(color: Colors.green),
          ),
        ),
      ],
    );
  }
}
