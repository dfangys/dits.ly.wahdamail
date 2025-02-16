import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/settings/data/swap_data.dart';
import '../../../app/controllers/settings_controller.dart';
import '../../../widgets/listile/show_dialog_box.dart';

class SwipGestureSetting extends GetView<SettingController> {
  SwipGestureSetting({super.key});
  final SwapSettingData data = SwapSettingData();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Swipe Gestures'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text("Left to right swipe"),
              InkWell(
                onTap: () {
                  showCupertinoModalPopup(
                    context: context,
                    builder: (context) => const Material(
                      child: ListTileCupertinoDilaogue(
                        direction: "LTR",
                      ),
                    ),
                  );
                },
                child: Obx(
                  () => data.swapActions[
                      getSwapActionFromString(controller.swipeGesturesLTR())]!,
                ),
              ),
              Divider(
                color: Colors.grey.shade300,
              ),
              const Text("Right to left swipe"),
              const SizedBox(height: 10),
              InkWell(
                onTap: () {
                  showCupertinoModalPopup(
                    context: context,
                    builder: (context) => const Material(
                      child: ListTileCupertinoDilaogue(
                        direction: "RTL",
                      ),
                    ),
                  );
                },
                child: Obx(
                  () => data.swapActions[
                      getSwapActionFromString(controller.swipeGesturesRTL())]!,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
