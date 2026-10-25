import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/theme/app_theme.dart';

class ShimmerLoader extends StatelessWidget {
  final int itemCount;
  const ShimmerLoader({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.all(AppTheme.spacingLg),
      itemCount: itemCount,
      separatorBuilder: (_, __) => SizedBox(height: AppTheme.spacingXl),
      itemBuilder: (_, __) => Container(
        height: 180,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.modernShadow,
        ),
        child: Column(
          children: [
            // Simuler l'en-tête de la carte (le dégradé)
            Shimmer.fromColors(
              baseColor: AppTheme.eptBlue.withOpacity(0.1),
              highlightColor: AppTheme.eptBlue.withOpacity(0.2),
              child: Container(
                height: 80,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),
            ),
            // Simuler le corps de la carte
            Padding(
              padding: EdgeInsets.all(AppTheme.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerTile(height: 14, width: 200, radius: 4),
                  SizedBox(height: AppTheme.spacingMd),
                  Row(
                    children: [
                      ShimmerTile(height: 24, width: 24, radius: 12),
                      SizedBox(width: AppTheme.spacingSm),
                      ShimmerTile(height: 12, width: 120, radius: 4),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShimmerTile extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;
  const ShimmerTile({
    super.key,
    this.height = 16,
    this.width,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceCard,
      highlightColor: AppTheme.surfaceLift,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
