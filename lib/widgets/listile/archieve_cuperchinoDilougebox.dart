import 'package:flutter/material.dart';

class ArchieveCupercionoDilaogeBox extends StatelessWidget {
  const ArchieveCupercionoDilaogeBox({
    super.key,
    required this.icon,
    required this.onTap,
    required this.text,
    required this.backgroundColor,
    required this.iconColor,
    this.textColor,
    required this.opacity,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String text;
  final Color backgroundColor;
  final Color iconColor;
  final Color? textColor;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Container(
          height: 80,
          width: 80,
          decoration: BoxDecoration(
              color: backgroundColor.withOpacity(opacity),
              borderRadius: BorderRadius.circular(10)),
          child: Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    color: iconColor,
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall!
                        .apply(color: textColor),
                  )
                ]),
          ),
        ),
      ),
    );
  }
}
