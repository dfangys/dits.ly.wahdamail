import 'package:flutter/material.dart';

class WDraweTile extends StatelessWidget {
  const WDraweTile({
    super.key,
    required this.image,
    required this.text,
    required this.onTap,
    this.trailing,
  });
  final dynamic image;
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
        child: image is IconData
            ? Icon(
                image,
                color: Colors.white,
              )
            : Image.asset(image),
      ),
      title: Text(
        text,
        style: const TextStyle(color: Colors.white),
      ),
      onTap: onTap,
      trailing: trailing == null || trailing!.isEmpty
          ? const SizedBox.shrink()
          : Container(
              padding: const EdgeInsets.all(5),
              width: 45,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Center(
                child: Text("$trailing"),
              ),
            ),
    );
  }
}
