import 'package:flutter/material.dart';

class WDraweTile extends StatelessWidget {
  const WDraweTile({
    super.key,
    required this.image,
    required this.text,
    required this.onTap,
    this.trailing,
  });
  final String image;
  final String text;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Container(
          margin: const EdgeInsets.only(left: 5),
          height: 20,
          width: 20,
          child: Image.asset(image)),
      title: Text(
        text,
        style: const TextStyle(color: Colors.white),
      ),
      onTap: onTap,
      trailing: Text(trailing.toString()),
    );
  }
}
