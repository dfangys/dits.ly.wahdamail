import 'package:flutter/material.dart';

class ProcessDialog extends StatelessWidget {
  const ProcessDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return const Dialog(
      backgroundColor: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(5),
        child: SizedBox(
          height: 100,
          width: 100,
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ),
    );
  }
}
