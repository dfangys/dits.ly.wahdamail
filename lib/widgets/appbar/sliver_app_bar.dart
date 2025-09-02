import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class WSliverAppBar extends StatelessWidget {
  const WSliverAppBar({super.key});

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
        title: Text('inbox'.tr, style: const TextStyle(color: Colors.black)),
        background: Container(
          width: double.infinity,
          color: Colors.grey.shade300,
        ),
      ),
      title: Row(
        children: [
          const Icon(CupertinoIcons.back, color: Colors.green),
          Text(
            'accounts'.tr,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium!.apply(color: Colors.green),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {},
          child: Text('edit'.tr, style: const TextStyle(color: Colors.green)),
        ),
      ],
    );
  }
}
