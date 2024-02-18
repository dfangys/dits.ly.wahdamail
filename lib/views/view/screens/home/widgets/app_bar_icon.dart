import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/compose/compose.dart';

class HomeAppBarIcon extends StatelessWidget {
  const HomeAppBarIcon({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Get.to(() => const ComposeScreen());
      },
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 10, right: 10, left: 10),
        height: 30,
        width: 30,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(5)),
          color: Colors.green,
        ),
        child: const Center(
            child: Icon(
          Icons.add,
          color: Colors.white,
        )),
      ),
    );
  }
}
