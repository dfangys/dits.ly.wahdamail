import 'package:flutter/material.dart';
import 'package:wahda_bank/widgets/custom_loading_button.dart';

class WRoundedButton extends StatelessWidget {
  const WRoundedButton({
    super.key,
    required this.controller,
    required this.onPress,
    required this.text,
  });
  final CustomLoadingButtonController controller;
  final String text;
  final Function()? onPress;

  @override
  Widget build(BuildContext context) {
    return CustomLoadingButton(
      color: Theme.of(context).primaryColor,
      borderRadius: 10,
      elevation: 3,
      width: MediaQuery.of(context).size.width - 40,
      controller: controller,
      onPressed: onPress,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16.0,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
