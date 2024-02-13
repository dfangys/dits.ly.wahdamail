import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';

class AccountNameSheet extends GetView<SettingController> {
  AccountNameSheet({super.key});
  final textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    textController.text = controller.accountName();
    return Material(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(15),
              topRight: Radius.circular(15),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  const Text("Name"),
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () {
                      controller.accountName(textController.text);
                      Navigator.pop(context);
                    },
                  )
                ],
              ),
              const Divider(),
              TextFormField(
                controller: textController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Enter your name',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
