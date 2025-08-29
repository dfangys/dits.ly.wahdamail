import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Gmail-like shimmer skeleton list for email rows.
/// Matches the general shape and spacing of MailTile for smooth transitions.
class ShimmerMailLoader extends StatelessWidget {
  const ShimmerMailLoader({super.key, this.itemCount = 12, this.padding});

  final int itemCount;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = isDark ? Colors.grey.shade800 : Colors.grey.shade200;
    final highlight = isDark ? Colors.grey.shade700 : Colors.grey.shade100;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding ?? const EdgeInsets.symmetric(vertical: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Shimmer.fromColors(
            baseColor: base,
            highlightColor: highlight,
            period: const Duration(milliseconds: 1200),
            child: Container(
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  // Avatar placeholder
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: base,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Text lines
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sender line
                        _shimmerBar(width: 160, height: 12, base: base),
                        const SizedBox(height: 8),
                        // Subject line
                        _shimmerBar(width: double.infinity, height: 10, base: base),
                        const SizedBox(height: 6),
                        // Preview line (half width)
                        _shimmerBar(width: MediaQuery.of(context).size.width * 0.5, height: 10, base: base),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Time pill placeholder
                  _shimmerBar(width: 44, height: 10, base: base, radius: 6),
                ],
              ),
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => Divider(
        height: 0,
        thickness: 0,
        color: Colors.transparent,
      ),
    );
  }

  Widget _shimmerBar({required double width, required double height, required Color base, double radius = 6}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
