import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class WAnimationLoaderWidget extends StatelessWidget {
  const WAnimationLoaderWidget(
      {super.key,
      required this.text,
      required this.animation,
      this.showAction = false,
      this.actionText,
      this.onActionPressed});
  final String text;
  final String animation;
  final bool showAction;
  final String? actionText;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.network(
            animation,
            width: MediaQuery.of(context).size.width * 0.8,
          ),
          const SizedBox(
            height: 24.0,
          ),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(
            height: 24.0,
          ),
          showAction
              ? SizedBox(
                  width: 250,
                  child: OutlinedButton(
                    onPressed: onActionPressed,
                    child: Text(
                      actionText!,
                      style: Theme.of(context).textTheme.bodyMedium!.apply(
                          color: const Color.fromARGB(255, 251, 247, 247)),
                    ),
                  ))
              : const SizedBox()
        ],
      ),
    );
  }
}
