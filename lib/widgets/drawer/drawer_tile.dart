import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class WDrawerTile extends StatelessWidget {
  const WDrawerTile({
    super.key,
    required this.icon,
    required this.text,
    required this.onTap,
    this.count = 0,
    this.isActive = false,
  });

  final IconData icon;
  final String text;
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withValues(alpha : 0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Icon with background
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withValues(alpha : 0.3)
                      : Colors.white.withValues(alpha : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              // Text
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 15,
                  ),
                ),
              ),

              // Count badge
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),

              // Arrow indicator for navigation
              if (count == 0)
                Icon(
                  Iconsax.arrow_right_3,
                  color: Colors.white.withValues(alpha : 0.5),
                  size: 16,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
