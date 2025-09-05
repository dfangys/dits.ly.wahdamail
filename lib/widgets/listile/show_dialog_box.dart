import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/features/settings/presentation/data/swap_data.dart';

class ListTileCupertinoDilaogue extends GetView<SettingController> {
  const ListTileCupertinoDilaogue({super.key, required this.direction});

  final String direction;

  @override
  Widget build(BuildContext context) {
    SwapSettingData data = SwapSettingData();
    return Container(
      padding: const EdgeInsets.all(25.0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(15),
          topRight: Radius.circular(15),
        ),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.2,
        ),
        itemBuilder: (context, index) {
          return InkWell(
            onTap: () {
              if (direction == "LTR") {
                controller.swipeGesturesLTR(
                  data.swapActions.keys.elementAt(index).name.toString(),
                );
              } else {
                controller.swipeGesturesRTL(
                  data.swapActions.keys.elementAt(index).name.toString(),
                );
              }
              Navigator.pop(context);
            },
            child: data.swapActions.values.elementAt(index),
          );
        },
        itemCount: data.swapActions.length,
      ),
    );
  }
}
