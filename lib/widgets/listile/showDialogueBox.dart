import 'package:flutter/material.dart';
import '../../views/settings/data/swap_data.dart';

class ListTileCupertinoDilaogue extends StatelessWidget {
  const ListTileCupertinoDilaogue({
    super.key,
  });

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
              print(data.swapActions.keys.elementAt(index));
            },
            child: data.swapActions.values.elementAt(index),
          );
        },
        itemCount: data.swapActions.length,
      ),
    );
  }
}
