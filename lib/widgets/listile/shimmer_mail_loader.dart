import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

class ShimmerMailLoader extends StatelessWidget {
  const ShimmerMailLoader({
    super.key,
    this.itemCount = 10,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar shimmer
              TShimmerEffect(
                width: 48,
                height: 48,
                radius: 24,
                color: AppTheme.primaryColor.withOpacity(0.1),
              ),
              const SizedBox(width: 16),

              // Content shimmer
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sender name shimmer
                    TShimmerEffect(
                      width: 150 + (index % 3) * 30, // Varied widths for natural look
                      height: 16,
                      radius: 4,
                      color: AppTheme.primaryColor.withOpacity(0.1),
                    ),
                    const SizedBox(height: 8),

                    // Subject shimmer
                    TShimmerEffect(
                      width: double.infinity,
                      height: 14,
                      radius: 4,
                      color: AppTheme.primaryColor.withOpacity(0.1),
                    ),
                    const SizedBox(height: 6),

                    // Preview text shimmer
                    TShimmerEffect(
                      width: double.infinity,
                      height: 12,
                      radius: 4,
                      color: AppTheme.primaryColor.withOpacity(0.1),
                    ),
                    const SizedBox(height: 4),

                    // Short preview text shimmer
                    TShimmerEffect(
                      width: 180 - (index % 4) * 20, // Varied widths for natural look
                      height: 12,
                      radius: 4,
                      color: AppTheme.primaryColor.withOpacity(0.1),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Time and indicators shimmer
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Time shimmer
                  TShimmerEffect(
                    width: 60,
                    height: 12,
                    radius: 4,
                    color: AppTheme.primaryColor.withOpacity(0.1),
                  ),
                  const SizedBox(height: 8),

                  // Indicator shimmer (attachment, etc.)
                  if (index % 3 == 0) // Only show on some items for realism
                    TShimmerEffect(
                      width: 20,
                      height: 20,
                      radius: 10,
                      color: AppTheme.primaryColor.withOpacity(0.1),
                    ),
                ],
              ),
            ],
          ),
        );
      },
      separatorBuilder: (context, index) => Divider(
        color: Colors.grey.shade200,
        height: 16,
        indent: 64,
        endIndent: 16,
      ),
    );
  }
}

class TShimmerEffect extends StatelessWidget {
  const TShimmerEffect({
    super.key,
    required this.width,
    required this.height,
    this.radius = 4,
    this.color,
  });

  final double width, height, radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      period: const Duration(milliseconds: 1500), // Slightly slower for smoother effect
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color ?? Colors.grey.shade200,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

// Message detail shimmer for showing when loading a specific email
class ShimmerMessageDetailLoader extends StatelessWidget {
  const ShimmerMessageDetailLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header section
          Row(
            children: [
              TShimmerEffect(
                width: 48,
                height: 48,
                radius: 24,
                color: AppTheme.primaryColor.withOpacity(0.1),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TShimmerEffect(
                      width: 180,
                      height: 18,
                      radius: 4,
                      color: AppTheme.primaryColor.withOpacity(0.1),
                    ),
                    const SizedBox(height: 8),
                    TShimmerEffect(
                      width: 140,
                      height: 14,
                      radius: 4,
                      color: AppTheme.primaryColor.withOpacity(0.1),
                    ),
                  ],
                ),
              ),
              TShimmerEffect(
                width: 80,
                height: 14,
                radius: 4,
                color: AppTheme.primaryColor.withOpacity(0.1),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Subject
          TShimmerEffect(
            width: double.infinity,
            height: 22,
            radius: 4,
            color: AppTheme.primaryColor.withOpacity(0.1),
          ),

          const SizedBox(height: 32),

          // Message content paragraphs
          for (int i = 0; i < 5; i++) ...[
            TShimmerEffect(
              width: double.infinity,
              height: 14,
              radius: 4,
              color: AppTheme.primaryColor.withOpacity(0.1),
            ),
            const SizedBox(height: 8),
            TShimmerEffect(
              width: double.infinity,
              height: 14,
              radius: 4,
              color: AppTheme.primaryColor.withOpacity(0.1),
            ),
            const SizedBox(height: 8),
            TShimmerEffect(
              width: 0.7 * MediaQuery.of(context).size.width,
              height: 14,
              radius: 4,
              color: AppTheme.primaryColor.withOpacity(0.1),
            ),
            const SizedBox(height: 24),
          ],

          // Attachments section
          TShimmerEffect(
            width: 120,
            height: 18,
            radius: 4,
            color: AppTheme.primaryColor.withOpacity(0.1),
          ),
          const SizedBox(height: 16),

          // Attachment items
          Row(
            children: [
              TShimmerEffect(
                width: 60,
                height: 60,
                radius: 8,
                color: AppTheme.primaryColor.withOpacity(0.1),
              ),
              const SizedBox(width: 16),
              TShimmerEffect(
                width: 60,
                height: 60,
                radius: 8,
                color: AppTheme.primaryColor.withOpacity(0.1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
