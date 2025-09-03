import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerMailLoader extends StatelessWidget {
  const ShimmerMailLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: 10,
      itemBuilder: (context, index) {
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: CircleAvatar(
                radius: 30,
                child: TShimmerEffect(
                  width: double.infinity,
                  height: 100,
                  radius: 100,
                ),
              ),
              title: TShimmerEffect(width: 100, height: 50),
              trailing: TShimmerEffect(width: 60, height: 20),
            ),
          ],
        );
      },
      separatorBuilder:
          (context, index) => Divider(color: Colors.grey.shade200),
    );
  }
}

class TShimmerEffect extends StatelessWidget {
  const TShimmerEffect({
    super.key,
    required this.width,
    required this.height,
    this.radius = 15,
    this.color,
  });
  final double width, height, radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade200,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
