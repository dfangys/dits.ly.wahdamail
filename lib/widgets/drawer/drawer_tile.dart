import 'package:flutter/material.dart';

class WDraweTile extends StatelessWidget {
  const WDraweTile({
    super.key,
    required this.image,
    required this.text,
    required this.onTap,
    this.trailing,
    this.isSelected = false,
  });

  final dynamic image;
  final String text;
  final String? trailing;
  final VoidCallback onTap;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.white.withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        leading: Container(
          margin: const EdgeInsets.only(left: 5),
          height: 24,
          width: 24,
          child: image is IconData
              ? Icon(
            image,
            color: Colors.white,
            size: 22,
          )
              : Image.asset(image),
        ),
        title: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: onTap,
        trailing: trailing == null || trailing!.isEmpty
            ? null
            : Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          constraints: const BoxConstraints(minWidth: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            trailing!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        visualDensity: VisualDensity.compact,
        minLeadingWidth: 24,
      ),
    );
  }
}
